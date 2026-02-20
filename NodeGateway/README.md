# Node.js API Gateway

The backend orchestrator for the Image Annotation System. Built with Express.js and MongoDB, it handles file uploads, data persistence, and communication with the Flask Computer Vision service.

## Features

- **API Gateway**: Central entry point for the Flutter client.
- **Image Uploads**: Handles multipart/form-data uploads using `multer`.
- **Data Persistence**: Stores image metadata and annotations in MongoDB.
- **Orchestration**: Forwards image processing requests to the FlaskCV service and aggregates results.
- **Geo-Spatial Queries**: Uses MongoDB's geospatial capabilities to filter images by location.

## API Endpoints

### 1. Upload Image

Uploads a single image and creates an annotation.

- **URL**: `/upload`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Fields**:
  - `image`: The image file.
  - `lat`: Latitude.
  - `lon`: Longitude.
  - `x`: Tap coordinate X.
  - `y`: Tap coordinate Y.
  - `description`: Annotation text.

### 2. Search Image

Searches for similar images within a geographic radius.

- **URL**: `/search`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Fields**:
  - `image`: The query image file.
  - `lat`: Latitude.
  - `lon`: Longitude.

### 3. Bulk Annotate

Uploads an image with multiple annotations.

- **URL**: `/bulk-annotate`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Fields**:
  - `image`: The image file.
  - `lat`: Latitude.
  - `lon`: Longitude.
  - `annotationsData`: JSON string array of objects `{x, y, description}`.

## Setup & Run

1.  Navigate into `NodeGateway/`:
    ```bash
    cd NodeGateway
    ```
2.  Install dependencies:
    ```bash
    npm install
    ```
3.  Start the server:
    ```bash
    npm start
    ```
    (Ensure MongoDB is running and `.env` is configured).

## Environment Variables

Create a `.env` file with:

```env
PORT=3000
MONGO_URI=mongodb://localhost:27017/image_annotation
FLASK_API_URL=http://localhost:5000
```
