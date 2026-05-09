<?php
require_once __DIR__ . '/../bootstrap.php';

Validator::validate($_POST, [
    'username' => 'required',
    'password' => 'required'
]);

$username = Security::sanitize($_POST['username']);
$password = $_POST['password'];

$db = DB::getInstance();
$user = $db->fetchOne(
    "SELECT u.*, w.balance 
     FROM users u 
     LEFT JOIN wallets w ON u.id = w.user_id 
     WHERE u.username = ? OR u.email = ?",
    [$username, $username]
);

if (!$user || !password_verify($password, $user['password_hash'])) {
    Response::error("Invalid credentials", 401);
}

if ($user['status'] !== 'active') {
    Response::error("Account is " . $user['status'], 403);
}

$token = Auth::generateToken($user['id']);

Response::success([
    'token' => $token,
    'user' => [
        'id' => (int)$user['id'],
        'username' => $user['username'],
        'display_name' => $user['display_name'],
        'role' => $user['role']
    ],
    'wallet_balance' => (float)$user['balance']
], "Login successful");
