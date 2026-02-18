import cv2
import numpy as np
import os
import joblib
from sklearn.neighbors import KDTree
import random

def extract_features(image_path, center_crop=False):
    print(f"Extracting features from {image_path} (Crop: {center_crop})")
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(f"Could not load image at {image_path}")
    
    if center_crop:
        h, w = image.shape[:2]
        # Take central 50%
        crop_h, crop_w = int(h * 0.5), int(w * 0.5)
        start_y, start_x = int(h * 0.25), int(w * 0.25)
        image = image[start_y:start_y+crop_h, start_x:start_x+crop_w]

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    sift = cv2.SIFT_create()
    keypoints, descriptors = sift.detectAndCompute(gray, None)
    
    return keypoints, descriptors, image.shape

def find_nearest_keypoint(keypoints, descriptors, x, y):
    """
    Finds the nearest SIFT keypoint to the user's tap (x, y).
    Returns (keypoint_index, descriptor).
    """
    if not keypoints:
        return None, None

    min_dist = float('inf')
    nearest_idx = -1

    for i, kp in enumerate(keypoints):
        # Calculate Euclidean distance
        dist = np.sqrt((kp.pt[0] - x)**2 + (kp.pt[1] - y)**2)
        if dist < min_dist:
            min_dist = dist
            nearest_idx = i

    if nearest_idx != -1:
        return nearest_idx, descriptors[nearest_idx]
    return None, None

def manage_tree(tree_path, descriptor):
    """
    Loads (or creates) a KD-Tree, adds the new descriptor, and saves it.
    Returns a unique keypoint_global_id.
    """
    tree_dir = os.path.dirname(tree_path)
    if not os.path.exists(tree_dir):
        os.makedirs(tree_dir)

    data = {'descriptors': [], 'ids': []}
    
    if os.path.exists(tree_path):
        try:
            data = joblib.load(tree_path)
        except Exception as e:
            print(f"Error loading tree {tree_path}: {e}")
            # Identify if corrupted, maybe backup or restart? For now, start fresh on error
            data = {'descriptors': [], 'ids': []}

    # Generate unique ID for this keypoint
    # For distributed systems, use UUID. For this demo, random large int is fine.
    keypoint_global_id = random.randint(1, 10**9)
    # Ensure uniqueness (simple check)
    while keypoint_global_id in data['ids']:
        keypoint_global_id = random.randint(1, 10**9)

    # Add new data
    data['descriptors'].append(descriptor)
    data['ids'].append(keypoint_global_id)

    # Rebuild Tree (sklearn KDTree is immutable, so we store data and rebuild when needed or just store raw data here)
    # Actually, for querying later, we need the *Tree* object.
    # But for *adding* one by one, we just store the list and rebuild.
    # Optimization: Only rebuild when querying? Or rebuild and save now?
    # Let's save the raw data principally, and maybe the built tree if large.
    # For now, just save the data. The Search function will load data and build/query.
    
    joblib.dump(data, tree_path)
    
    return keypoint_global_id

def build_and_query_tree(tree_paths, query_descriptors, ratio_thresh=0.75):
    """
    Loads data from multiple tree files, builds a single KD-Tree (or one per file),
    and queries for matches.
    Returns a list of matched keypoint_global_ids.
    """
    all_descriptors = []
    all_ids = []

    for path in tree_paths:
        if os.path.exists(path):
            try:
                data = joblib.load(path)
                if data['descriptors']:
                    all_descriptors.extend(data['descriptors'])
                    all_ids.extend(data['ids'])
            except:
                continue
    
    if not all_descriptors:
        return []

    # Build KD-Tree
    X = np.array(all_descriptors)
    tree = KDTree(X)

    # Query
    # For each descriptor in query image, find 2 nearest neighbors in the tree
    matched_ids = []
    
    # We need at least 2 points for ratio test, but if tree is small, k=1?
    k = 2 if len(all_descriptors) >= 2 else 1
    
    dists, inds = tree.query(query_descriptors, k=k)

    for i in range(len(query_descriptors)):
        if k == 2:
            # Lowe's Ratio Test
            if dists[i][0] < ratio_thresh * dists[i][1]:
                global_id = all_ids[inds[i][0]]
                matched_ids.append(global_id)
        elif k == 1:
            # Simple threshold?
            if dists[i][0] < 200: # Arbitrary threshold for SIFT distance
                 global_id = all_ids[inds[i][0]]
                 matched_ids.append(global_id)

    return list(set(matched_ids))
