<?php
// API Bootstrap

error_reporting(E_ALL);
ini_set('display_errors', 0); // Hide errors in production

require_once __DIR__ . '/core/db.php';
require_once __DIR__ . '/core/response.php';
require_once __DIR__ . '/core/auth.php';
require_once __DIR__ . '/core/validator.php';
require_once __DIR__ . '/core/security.php';
require_once __DIR__ . '/core/moderation.php';

// Setup CORS and Headers
Security::setupHeaders();

// Global Exception Handler
set_exception_handler(function($e) {
    Response::error($e->getMessage(), 500);
});

// JSON Input Helper
$input = json_decode(file_get_contents('php://input'), true) ?? [];
$_POST = array_merge($_POST, $input);
