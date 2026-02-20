# Flask Computer Vision Service (FlaskCV)

This service provides computer vision capabilities to the Image Annotation System. It uses OpenCV to extract SIFT/ORB features from images and manages KD-Trees for fast visual similarity search.

## Features

- **Feature Extraction**: Extracts keypoints and descriptors from uploaded images.
- **KD-Tree Management**: Builds and manages KD-Trees for efficient nearest neighbor search of image descriptors.
- **Visual Search**: Queries multiple KD-Trees to find images matching a query image's descriptors.

## API Endpoints

### 1. Process Image

Extracts features from an image and updates/creates its KD-Tree.

- **URL**: `/process`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "filename": "image.jpg",
    "x": 100, // Touch coordinate X
    "y": 200 // Touch coordinate Y
  }
  ```
- **Response**: Returns the `keypointId` and `treeId`.

### 2. Search Image

Searches for similar images across a set of KD-Trees.

- **URL**: `/search`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "filename": "query_image.jpg",
    "tree_ids": ["image1.pkl", "image2.pkl"]
  }
  ```
- **Response**: Returns a list of matches.

## Local Setup

1.  Navigate into `FlaskCV/`:
    ```bash
    cd FlaskCV
    ```
2.  Install dependencies (ensure you have Python installed):
    ```bash
    pip install flask opencv-python numpy
    ```
3.  Run the application:

    ```bash
    # Linux/Mac
    export FLASK_APP=app.py
    flask run --host=0.0.0.0 --port=5000

    # Windows (PowerShell)
    $env:FLASK_APP = "app.py"
    flask run --host=0.0.0.0 --port=5000
    ```
