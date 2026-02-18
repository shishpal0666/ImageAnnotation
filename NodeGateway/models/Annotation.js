const mongoose = require('mongoose');

const AnnotationSchema = new mongoose.Schema({
  imageId: mongoose.Schema.Types.ObjectId,
  keypointId: Number, // The ID returned by Flask
  description: String,
  coordinates: { x: Number, y: Number } // Store where the user tapped for reference
});

module.exports = mongoose.model('Annotation', AnnotationSchema);
