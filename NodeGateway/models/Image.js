const mongoose = require('mongoose');

const ImageSchema = new mongoose.Schema({
  filename: String,
  uploadDate: { type: Date, default: Date.now },
  location: {
    type: { type: String, default: 'Point' },
    coordinates: [Number] // [Longitude, Latitude] - MongoDB expects [Lon, Lat]
  },
  kdTreeId: String // ID of the KD-Tree this image belongs to
});

// Create a geospatial index for fast location searching
ImageSchema.index({ location: '2dsphere' }); 

module.exports = mongoose.model('Image', ImageSchema);
