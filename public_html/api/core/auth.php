<?php

class Auth {
    private static $currentUser = null;

    public static function generateToken($userId) {
        $token = bin2hex(random_bytes(32));
        $hash = hash('sha256', $token);
        $expiry = date('Y-m-d H:i:s', strtotime('+30 days'));

        $db = DB::getInstance();
        $db->query(
            "INSERT INTO user_sessions (user_id, token_hash, expires_at) VALUES (?, ?, ?)",
            [$userId, $hash, $expiry]
        );

        return $token;
    }

    public static function authenticate() {
        $headers = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

        if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            return null;
        }

        $token = $matches[1];
        $hash = hash('sha256', $token);

        $db = DB::getInstance();
        $session = $db->fetchOne(
            "SELECT us.*, u.username, u.display_name, u.role, u.status 
             FROM user_sessions us 
             JOIN users u ON us.user_id = u.id 
             WHERE us.token_hash = ? AND us.expires_at > NOW() AND us.revoked_at IS NULL",
            [$hash]
        );

        if (!$session) {
            return null;
        }

        if ($session['status'] !== 'active') {
            return null;
        }

        // Update last seen
        $db->query("UPDATE user_sessions SET last_seen_at = NOW() WHERE id = ?", [$session['id']]);

        self::$currentUser = $session;
        return $session;
    }

    public static function user() {
        return self::$currentUser;
    }

    public static function userId() {
        return self::$currentUser['user_id'] ?? null;
    }

    public static function requireAuth() {
        if (!self::authenticate()) {
            Response::unauthorized();
        }
    }

    public static function requireRole($roles) {
        self::requireAuth();
        if (!in_array(self::$currentUser['role'], (array)$roles)) {
            Response::forbidden();
        }
    }
}
