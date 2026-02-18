from flask import Flask, request, jsonify
import os
import cv_engine

app = Flask(__name__)

UPLOAD_FOLDER = '/app/uploads'
TREE_FOLDER = os.path.join(UPLOAD_FOLDER, 'trees')

if not os.path.exists(TREE_FOLDER):
    os.makedirs(TREE_FOLDER)

@app.route('/process', methods=['POST'])
def process_image():
    try:
        data = request.json
        filename = data.get('filename')
        x = data.get('x')
        y = data.get('y')

        if not filename or x is None or y is None:
            return jsonify({'error': 'Missing filename, x, or y'}), 400

        image_path = os.path.join(UPLOAD_FOLDER, filename)
        
        # Extract Features
        keypoints, descriptors, _ = cv_engine.extract_features(image_path)
        
        if keypoints is None or len(keypoints) == 0:
             return jsonify({'error': 'No keypoints found in image'}), 400

        # Find Nearest Keypoint
        kp_idx, descriptor = cv_engine.find_nearest_keypoint(keypoints, descriptors, x, y)
        
        if kp_idx is None:
             return jsonify({'error': 'No keypoint found near tap'}), 400

        # Update KD-Tree
        # Strategy: Use one tree per image for now to allow granular loading
        tree_id = f"{filename}.pkl"
        tree_path = os.path.join(TREE_FOLDER, tree_id)
        
        keypoint_id = cv_engine.manage_tree(tree_path, descriptor)

        return jsonify({
            'keypointId': keypoint_id,
            'treeId': tree_id
        })

    except Exception as e:
        print(f"Error in /process: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/search', methods=['POST'])
def search_image():
    try:
        data = request.json
        filename = data.get('filename')
        tree_ids = data.get('tree_ids')

        if not filename or not tree_ids:
            return jsonify({'error': 'Missing filename or tree_ids'}), 400

        image_path = os.path.join(UPLOAD_FOLDER, filename)

        # Extract Descriptors from Query Image (Center Crop)
        # Note: We don't need keypoints spatial info for the query, just descriptors
        _, query_descriptors, _ = cv_engine.extract_features(image_path, center_crop=True)

        if query_descriptors is None:
             return jsonify({'keypointIds': []})

        # Load Trees and Query
        tree_paths = [os.path.join(TREE_FOLDER, tid) for tid in tree_ids]
        
        matched_ids = cv_engine.build_and_query_tree(tree_paths, query_descriptors)

        return jsonify({'keypointIds': matched_ids})

    except Exception as e:
        print(f"Error in /search: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
