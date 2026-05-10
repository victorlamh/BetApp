<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error("Method not allowed", 405);
}

if (!isset($_FILES['avatar'])) {
    Response::error("No image uploaded");
}

$file = $_FILES['avatar'];
$userId = Auth::userId();

// Validate file
$allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
if (!in_array($file['type'], $allowedTypes)) {
    Response::error("Invalid file type. Only JPG, PNG and WEBP allowed.");
}

$maxSize = 5 * 1024 * 1024; // 5MB
if ($file['size'] > $maxSize) {
    Response::error("File too large. Max 5MB.");
}

// Create uploads directory if not exists
$uploadDir = __DIR__ . '/../../uploads/avatars/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Generate unique filename
$extension = pathinfo($file['name'], PATHINFO_EXTENSION);
if (!$extension) {
    $extension = ($file['type'] === 'image/jpeg') ? 'jpg' : (($file['type'] === 'image/png') ? 'png' : 'webp');
}
$filename = 'user_' . $userId . '_' . time() . '.' . $extension;
$uploadPath = $uploadDir . $filename;

if (move_uploaded_file($file['tmp_name'], $uploadPath)) {
    $db = DB::getInstance();
    $avatarUrl = 'https://' . $_SERVER['HTTP_HOST'] . '/uploads/avatars/' . $filename;
    
    $db->query("UPDATE users SET avatar_url = ? WHERE id = ?", [$avatarUrl, $userId]);
    
    Response::success(['avatar_url' => $avatarUrl], "Profile picture updated");
} else {
    Response::error("Failed to save uploaded file");
}
