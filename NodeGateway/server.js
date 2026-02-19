const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");
const multer = require("multer");
const axios = require("axios");
const path = require("path");
const fs = require("fs");

const connectDB = require("./database");
const Image = require("./models/Image");
const Annotation = require("./models/Annotation");

// Load env vars
dotenv.config();

// Connect to database
connectDB();

const PORT = process.env.PORT || 3000;

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ensure upload directory exists
const uploadDir = "/app/uploads";
if (!fs.existsSync(uploadDir)) {
  try {
    fs.mkdirSync(uploadDir, { recursive: true });
    console.log(`Created upload directory at ${uploadDir}`);
  } catch (err) {
    console.error(`Failed to create upload directory at ${uploadDir}:`, err);
  }
}

// Multer Storage Configuration
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    // Unique filename to prevent overwrites
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  },
});

const upload = multer({ storage: storage });

// Routes
// POST /upload
app.post("/upload", upload.single("image"), async (req, res) => {
  try {
    console.log("Received upload request");
    const { lat, lon, x, y, description } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ error: "No image file uploaded" });
    }

    console.log(`File saved: ${file.filename}`);

    // Save Image Metadata to MongoDB
    const newImage = new Image({
      filename: file.filename,
      location: {
        type: "Point",
        coordinates: [parseFloat(lon), parseFloat(lat)], // GeoJSON: [Longitude, Latitude]
      },
      // kdTreeId: TODO: Assign later or receive from client?
    });

    const savedImage = await newImage.save();
    console.log(`Image metadata saved: ${savedImage._id}`);

    // Call Flask Service
    const flaskServiceUrl = "http://flask_cv:5000/process";
    console.log(`Calling Flask service at ${flaskServiceUrl}`);

    // Flask expects: { filename: "...", x: 123, y: 456 }
    const flaskPayload = {
      filename: file.filename,
      x: parseFloat(x),
      y: parseFloat(y),
    };

    const flaskResponse = await axios.post(flaskServiceUrl, flaskPayload);
    console.log("Flask response:", flaskResponse.data);

    const { keypointId, treeId } = flaskResponse.data;

    // Update Image with kdTreeId
    if (treeId) {
      savedImage.kdTreeId = treeId;
      await savedImage.save();
      console.log(`Updated Image with kdTreeId: ${treeId}`);
    }

    // Save Annotation to MongoDB
    const newAnnotation = new Annotation({
      imageId: savedImage._id,
      keypointId: keypointId,
      description: description,
      coordinates: { x: parseFloat(x), y: parseFloat(y) },
    });

    await newAnnotation.save();
    console.log(`Annotation saved: ${newAnnotation._id}`);

    // Return Success
    res.status(201).json({
      message: "Success",
      imageId: savedImage._id,
      annotationId: newAnnotation._id,
      keypointId: keypointId,
    });
  } catch (error) {
    console.error("Error processing upload:", error);
    res
      .status(500)
      .json({ error: "Internal Server Error", details: error.message });
  }
});

// POST /search
app.post("/search", upload.single("image"), async (req, res) => {
  try {
    const { lat, lon } = req.body;
    const file = req.file;

    if (!file || !lat || !lon) {
      return res.status(400).json({ error: "Missing image, lat, or lon" });
    }

    console.log(
      `Search request received. Lat: ${lat}, Lon: ${lon}, File: ${file.filename}`,
    );

    // Geo-Filter: Find images within 5 meters
    const nearbyImages = await Image.find({
      location: {
        $near: {
          $geometry: {
            type: "Point",
            coordinates: [parseFloat(lon), parseFloat(lat)],
          },
          $maxDistance: 1000, // meters
        },
      },
    });

    console.log(`Found ${nearbyImages.length} nearby images.`);

    // Extract kdTreeIds, filtering out images without one
    const treeIds = nearbyImages.map((img) => img.kdTreeId).filter((id) => id);

    if (treeIds.length === 0) {
      console.log("No nearby images have valid kdTreeIds.");
      return res.json([]); // No potential matches
    }

    // Call Flask Service
    const flaskServiceUrl = "http://flask_cv:5000/search";
    const flaskPayload = {
      filename: file.filename,
      tree_ids: treeIds,
    };

    console.log(
      `Calling Flask search at ${flaskServiceUrl} with ${treeIds.length} tree IDs.`,
    );
    const flaskResponse = await axios.post(flaskServiceUrl, flaskPayload);
    const { matches } = flaskResponse.data; // Expecting { matches: [{id: 1, score: 0.1}, ...] }

    console.log(`Flask returned ${matches ? matches.length : 0} matches.`);

    if (!matches || matches.length === 0) {
      return res.json([]);
    }

    const keypointIds = matches.map((m) => m.id);

    // Query Mongo for Annotations
    const annotations = await Annotation.find({
      keypointId: { $in: keypointIds },
    });

    console.log(`Found ${annotations.length} annotations in DB.`);

    // Re-sort annotations based on Flask's score order
    const sortedAnnotations = matches
      .map((match) => {
        const annotation = annotations.find((a) => a.keypointId == match.id);
        return annotation
          ? { ...annotation.toObject(), score: match.score }
          : null;
      })
      .filter((item) => item !== null);

    // Return Annotations
    res.json(sortedAnnotations);
  } catch (error) {
    console.error("Error processing search:", error);
    res
      .status(500)
      .json({ error: "Internal Server Error", details: error.message });
  }
});

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
