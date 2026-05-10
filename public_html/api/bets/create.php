<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

// DEBUG: Log everything to see what's happening
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] Create Bet Attempt. Data: " . file_get_contents('php://input') . "\n", FILE_APPEND);

// Manual data capture to be 100% sure
$json = json_decode(file_get_contents('php://input'), true);
$data = !empty($json) ? $json : $_POST;

$title = $data['title'] ?? '';
$closeAt = $data['close_at'] ?? '';
$outcomes = $data['outcomes'] ?? [];

if (empty($title) || empty($closeAt) || empty($outcomes)) {
    Response::error("Missing fields. Title, Close Date, and Outcomes are all required.", 400);
}

$db = DB::getInstance();
$userId = Auth::userId();

try {
    $db->beginTransaction();

    $db->query(
        "INSERT INTO bets (creator_user_id, title, description, category, visibility, close_at, proof_required, status) 
         VALUES (?, ?, ?, ?, ?, ?, ?, 'pending_review')",
        [
            $userId,
            Security::sanitize($title),
            Security::sanitize($data['description'] ?? ''),
            Security::sanitize($data['category'] ?? 'General'),
            $data['visibility'] ?? 'friends',
            $closeAt,
            isset($data['proof_required']) ? (int)$data['proof_required'] : 1
        ]
    );
    file_put_contents(__DIR__ . '/../debug_log.txt', "BET INSERTED. ID: " . $db->lastInsertId() . "\n", FILE_APPEND);
    $betId = $db->lastInsertId();

    foreach ($outcomes as $index => $outcome) {
        $db->query(
            "INSERT INTO bet_outcomes (bet_id, label, initial_coefficient, sort_order) VALUES (?, ?, ?, ?)",
            [$betId, Security::sanitize($outcome['label']), $outcome['coefficient'], $index]
        );
    }

    // Create initial moderation review
    $db->query(
        "INSERT INTO moderation_reviews (bet_id, review_type, status) VALUES (?, 'publication', 'pending')",
        [$betId]
    );

    // Notify Admins
    $db->query(
        "INSERT INTO notifications (user_id, type, message, related_id) 
         SELECT id, 'bet_pending', ?, ? FROM users WHERE role = 'admin'",
        ["New bet pending review: " . Security::sanitize($title), $betId]
    );

    $db->commit();
    Response::success(['bet_id' => (int)$betId], "Bet submitted for review");

} catch (Exception $e) {
    $db->rollBack();
    file_put_contents(__DIR__ . '/../debug_log.txt', "SQL ERROR: " . $e->getMessage() . "\n", FILE_APPEND);
    Response::error("Failed to create bet: " . $e->getMessage());
}
