<?php

class Security {
    public static function setupHeaders() {
        $config = require __DIR__ . '/../config/env.php';
        $allowedOrigins = $config['security']['allowed_origins'] ?? ['*'];
        
        $origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
        if (in_array('*', $allowedOrigins) || in_array($origin, $allowedOrigins)) {
            header("Access-Control-Allow-Origin: $origin");
        }
        
        header("Access-Control-Allow-Methods: GET, POST, OPTIONS, DELETE, PUT");
        header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
        
        if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
            exit;
        }
    }

    public static function sanitize($data) {
        if ($data === null) return null;
        if (is_array($data)) {
            foreach ($data as $key => $value) {
                $data[$key] = self::sanitize($value);
            }
        } else {
            $data = htmlspecialchars(trim($data), ENT_QUOTES, 'UTF-8');
        }
        return $data;
    }
}
