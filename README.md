# Image Annotation & Retrieval System

**ImageAnnotation** is a multi-service platform for image annotation and visual search, built with a Flutter front-end, a Node.js API gateway, and a Flask/OpenCV computer-vision backend.

At a high level, the platform lets users:

- **Capture or pick an image.**
- **Add one or multiple annotations** (tap points + text descriptions).
- **Attach geolocation** to each image.
- **Search** with a new query image and location to retrieve ranked annotation matches from nearby images.

---

## 2. Architecture Summary

The system follows a 3-tier service architecture with storage split across MongoDB and a shared usage volume.

- **Presentation Layer**: [FlutterApp](./FlutterApp/README.md) for camera, annotation UI, and results rendering.
- **API Orchestration Layer**: [NodeGateway](./NodeGateway/README.md) (Node/Express) for upload handling, geospatial filtering, DB I/O, and routing CV requests.
- **CV Processing Layer**: [FlaskCV](./FlaskCV/README.md) for SIFT feature extraction and KDTree-based matching.
- **Data Layer**: MongoDB (image/annotation metadata) + Shared Docker volume (`media_data`) for images and tree artifacts.

![Architecture Diagram](./Assets/ImageAnnotationArchitecture.png)

---

## 3. Repository Structure

### Root

- `docker-compose.yml`: Runs `node_gateway`, `flask_cv`, and `flutter_app` containers and defines shared volume `media_data`.
- `README.md`: This file.

### [NodeGateway/](./NodeGateway/README.md)

- `server.js`: Main Express app, routes (`/upload`, `/search`, `/bulk-annotate`), static image hosting, CORS, and Flask integration.
- `database.js`: MongoDB connection helper.
- `models/Image.js`: Image metadata schema with geospatial index and `kdTreeId` linkage.
- `models/Annotation.js`: Annotation schema keyed by `imageId` and `keypointId`.
- `Dockerfile`, `package.json`, `package-lock.json`.

### [FlaskCV/](./FlaskCV/README.md)

- `app.py`: Flask API exposing `/process` and `/search`.
- `cv_engine.py`: CV primitives (SIFT extraction, nearest keypoint, KDTree persistence, and matching logic).
- `requirements.txt`, `Dockerfile`.

### [FlutterApp/](./FlutterApp/README.md)

- `lib/main.dart`: App entry point, home view, camera/search flows, mandatory location gating.
- `lib/screens/annotation_screen.dart`: Multi-annotation UX and batch submit.
- `lib/screens/results_screen.dart`: Ranked result list and image display.
- `lib/services/api_service.dart`: HTTP multipart API client for Node routes.
- `lib/models/local_annotation.dart`: local annotation DTO.
- `lib/models/annotation_result.dart`: result DTO and backend response adaptation.
- Platform scaffolding in `android/`, `ios/`, `web/`, `linux/`, `windows/`, `macos/`.

---

## 4. Service-by-Service Deep Dive

### 4.1 Flutter Front-End ([FlutterApp](./FlutterApp/README.md))

**Core Responsibilities:**

- Capture/pick images using `camera` and `image_picker`.
- Collect precise location using `geolocator`.
- Support two modes:
  - **Annotation Mode**: User marks points and descriptions.
  - **Search Mode**: User submits query image + location for match retrieval.
- Send multipart requests to Node gateway.

**Main UI/Flow:**

1.  **Home Screen**: Actions for "Add Annotation" and "Search".
2.  **CameraScreen**: Initializes camera, falls back gracefully, requires location.
3.  **AnnotationScreen**: Displays image, captures tap coordinates + text, sends via `/bulk-annotate`.
4.  **ResultsScreen**: Displays ranked matches with scores and loaded images.

**API Integration:**

- `ApiService` support:
  - `submitBatchAnnotations()` -> `POST /bulk-annotate`
  - `uploadAnnotation()` -> `POST /upload`
  - `searchImage()` -> `POST /search`
- Supports web/non-web file upload handling and configurable `API_BASE_URL`.

### 4.2 Node Gateway ([NodeGateway](./NodeGateway/README.md))

**Core Responsibilities:**

- Handle image upload via `multer`.
- Serve uploaded image files statically through `/uploads`.
- Persist metadata in MongoDB.
- Delegate feature extraction/matching to Flask CV service.
- Aggregate ranked matches with annotation text and image URLs.

**Database Models:**

- **Image**: `filename`, `uploadDate`, `location` (GeoJSON Point `[lon, lat]`), `kdTreeId` (2dsphere geospatial index).
- **Annotation**: `imageId`, `keypointId`, `description`, `coordinates` (`x`, `y`).

**Key API Endpoints:**

- `POST /upload`: Save image -> Create Image Doc -> Call Flask `/process` -> Save `treeId` -> Save Annotation.
- `POST /bulk-annotate`: Save image -> Loop annotations -> Call Flask `/process` for each -> Save Annotations -> Save final `treeId`.
- `POST /search`: Save query image -> Geo-filter candidates (`$near`) -> Extract `kdTreeId`s -> Call Flask `/search` -> Resolve keypoints to Annotations -> Return ranked list with URLs.

### 4.3 Flask CV Service ([FlaskCV](./FlaskCV/README.md))

**Core Responsibilities:**

- Extract visual descriptors from images.
- Map user tap to nearest keypoint descriptor.
- Persist/load per-image KDTree artifacts.
- Search query descriptors against candidate trees.

**Endpoint Behavior:**

- `POST /process`: Loads image -> Extracts SIFT -> Finds nearest keypoint -> Adds to KDTree (`trees/<filename>.pkl`) -> Returns `keypointId` + `treeId`.
- `POST /search`: Loads query image -> Extracts descriptors (center crop) -> Loads candidate trees -> Runs KDTree NN matching + ratio test -> Returns ranked matches.

**CV/ML Implementation Notes:**

- Uses `opencv-python-headless` + SIFT.
- Uses `sklearn.neighbors.KDTree` for NN indexing.
- Uses `joblib` for serialization.
- Includes basic corrupted-tree recovery.

---

## 5. Data and Storage Architecture

### 5.1 MongoDB Metadata

Stores lightweight metadata and relational links:

- Image records with geospatial coordinates and tree IDs.
- Annotation records with semantic text and keypoint linkage.

### 5.2 Shared Volume (`media_data`)

Mounted at `/app/uploads` in Node + Flask:

- Uploaded source images.
- `trees/*.pkl` KDTree artifacts.

_This avoids redundant blob storage duplication and allows both services to read the same artifacts._

---

## 6. End-to-End Request Flows

### 6.1 Annotate (Single / Bulk)

1.  **Flutter** sends multipart image + location + annotation points.
2.  **Node** persists image and metadata.
3.  **Node** calls **Flask** for descriptor/keypoint processing.
4.  **Flask** updates KDTree and returns keypoint identity.
5.  **Node** persists annotations and responds success.

### 6.2 Search

1.  **Flutter** sends query image + current location.
2.  **Node** geo-filters candidate images in MongoDB (`$near`).
3.  **Node** passes candidate trees to **Flask**.
4.  **Flask** computes ranked descriptor matches.
5.  **Node** maps keypoint IDs to annotations and enriches with image URLs.
6.  **Flutter** renders ranked descriptions and images.

---

## 7. Configuration and Deployment

### 7.1 Docker Compose Services

- `node_gateway` on port **3000**
- `flask_cv` on port **5000**
- `flutter_app` on port **8080**

### 7.2 Important Environment Variables

- `MONGO_URI`: Node DB connection.
- `FLASK_API_URL`: Node -> Flask route target.
- `FRONTEND_URL`: Node CORS allowlist.
- `BACKEND_PUBLIC_URL`: Base URL used for generated image links.

### 7.3 Networking Pattern

- Flutter talks to Node over HTTP.
- Node talks to Flask over internal service DNS (`flask_cv`).
- Node and Flask share the same volume mount path.

## Getting Started

To run the entire system:

```bash
docker-compose up --build
```
