const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const cors = require('cors');
const multer = require('multer');
const axios = require('axios');
const path = require('path');
const fs = require('fs');

const connectDB = require('./database');
const Image = require('./models/Image');
const Annotation = require('./models/Annotation');

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
const uploadDir = '/app/uploads';
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
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// Routes
// POST /upload
app.post('/upload', upload.single('image'), async (req, res) => {
  try {
    console.log('Received upload request');
    const { lat, lon, x, y, description } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ error: 'No image file uploaded' });
    }

    console.log(`File saved: ${file.filename}`);

    // Save Image Metadata to MongoDB
    const newImage = new Image({
      filename: file.filename,
      location: {
        type: 'Point',
        coordinates: [parseFloat(lon), parseFloat(lat)] // GeoJSON: [Longitude, Latitude]
      }
      // kdTreeId: TODO: Assign later or receive from client?
    });

    const savedImage = await newImage.save();
    console.log(`Image metadata saved: ${savedImage._id}`);

    // Call Flask Service
    const flaskServiceUrl = 'http://flask_cv:5000/process';
    console.log(`Calling Flask service at ${flaskServiceUrl}`);
    
    // Flask expects: { filename: "...", x: 123, y: 456 }
    const flaskPayload = {
      filename: file.filename,
      x: parseFloat(x),
      y: parseFloat(y)
    };

    const flaskResponse = await axios.post(flaskServiceUrl, flaskPayload);
    console.log('Flask response:', flaskResponse.data);

    const { keypointId } = flaskResponse.data;

    // Save Annotation to MongoDB
    const newAnnotation = new Annotation({
      imageId: savedImage._id,
      keypointId: keypointId,
      description: description,
      coordinates: { x: parseFloat(x), y: parseFloat(y) }
    });

    await newAnnotation.save();
    console.log(`Annotation saved: ${newAnnotation._id}`);

    // Return Success
    res.status(201).json({
      message: 'Success',
      imageId: savedImage._id,
      annotationId: newAnnotation._id,
      keypointId: keypointId
    });

  } catch (error) {
    console.error('Error processing upload:', error);
    res.status(500).json({ error: 'Internal Server Error', details: error.message });
  }
});

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
