<?php
require_once __DIR__ . '/../bootstrap.php';

Validator::validate($_POST, [
    'username' => 'required|min:3|max:50',
    'display_name' => 'required|min:2|max:100',
    'password' => 'required|min:6'
]);

$username = Security::sanitize($_POST['username']);
$displayName = Security::sanitize($_POST['display_name']);
$email = !empty($_POST['email']) ? Security::sanitize($_POST['email']) : null;
$passwordHash = password_hash($_POST['password'], PASSWORD_DEFAULT);

// DEBUG LOGGING
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] Reg Attempt: User=" . ($_POST['username'] ?? 'MISSING') . " Data=" . json_encode($_POST) . "\n", FILE_APPEND);

$db = DB::getInstance();

// Check uniqueness
$existing = $db->fetchOne("SELECT id, username FROM users WHERE username = ?", [$username]);
if ($existing) {
    file_put_contents(__DIR__ . '/../debug_log.txt', "CONFLICT: Username $username already exists with ID " . $existing['id'] . "\n", FILE_APPEND);
    Response::error("Username '$username' is already taken.", 409);
}

try {
    $db->beginTransaction();

    // Create User
    $db->query(
        "INSERT INTO users (username, display_name, email, password_hash) VALUES (?, ?, ?, ?)",
        [$username, $displayName, $email, $passwordHash]
    );
    $userId = $db->lastInsertId();

    // Create Wallet
    $db->query("INSERT INTO wallets (user_id, balance) VALUES (?, 100.00)", [$userId]);

    // Ledger Entry
    $db->query(
        "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, notes) 
         VALUES (?, 'seed', 100.00, 0.00, 100.00, 'Initial seed balance')",
        [$userId]
    );

    $token = Auth::generateToken($userId);
    $db->commit();

    file_put_contents(__DIR__ . '/../debug_log.txt', "SUCCESS: User $username created with ID $userId\n", FILE_APPEND);

    ob_clean(); // Clear any accidental whitespace or warnings
    Response::success([
        'token' => $token,
        'user' => [
            'id' => (int)$userId,
            'username' => $username,
            'display_name' => $displayName,
            'role' => 'player'
        ],
        'wallet_balance' => 100.00
    ], "Registration successful");

} catch (Exception $e) {
    $db->rollBack();
    file_put_contents(__DIR__ . '/../debug_log.txt', "SQL ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    Response::error("Registration failed: " . $e->getMessage());
}
