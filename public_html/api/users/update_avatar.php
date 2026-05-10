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

file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] update_avatar: userId=$userId file=" . $file['name'] . " size=" . $file['size'] . " type=" . $file['type'] . "\n", FILE_APPEND);

// Validate file
$allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
if (!in_array($file['type'], $allowedTypes)) {
    file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] update_avatar ERROR: Invalid type " . $file['type'] . "\n", FILE_APPEND);
    Response::error("Invalid file type. Only JPG, PNG and WEBP allowed.");
}

$maxSize = 10 * 1024 * 1024; // 10MB
if ($file['size'] > $maxSize) {
    file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] update_avatar ERROR: File too large " . $file['size'] . "\n", FILE_APPEND);
    Response::error("File too large. Max 10MB.");
}

// Create uploads directory if not exists
$uploadDir = __DIR__ . '/../../uploads/avatars/';
if (!file_exists($uploadDir)) {
    if (!mkdir($uploadDir, 0755, true)) {
        file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] update_avatar ERROR: Could not create dir $uploadDir\n", FILE_APPEND);
        Response::error("Failed to create upload directory");
    }
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
    
    file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] update_avatar SUCCESS: $avatarUrl\n", FILE_APPEND);
    
    $db->query("UPDATE users SET avatar_url = ? WHERE id = ?", [$avatarUrl, $userId]);
    
    Response::success(['avatar_url' => $avatarUrl], "Profile picture updated");
} else {
    file_put_contents(__DIR__ . '/../../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] update_avatar ERROR: move_uploaded_file failed to $uploadPath\n", FILE_APPEND);
    Response::error("Failed to save uploaded file");
}
