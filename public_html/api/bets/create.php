<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

// Use a more flexible validation for outcomes
$errors = [];
if (empty($_POST['title'])) $errors[] = "Title is required";
if (empty($_POST['close_at'])) $errors[] = "Closing date is required";
if (empty($_POST['outcomes'])) $errors[] = "Outcomes are required";

if (!empty($errors)) {
    file_put_contents(__DIR__ . '/../debug_log.txt', "VALIDATION FAILED: " . json_encode($errors) . " Received: " . json_encode($_POST) . "\n", FILE_APPEND);
    Response::error("Validation failed: " . implode(", ", $errors), 400);
}

// Safety Scan
$scanResult = Moderation::scan($_POST['title'] . ' ' . ($_POST['description'] ?? ''));
if (!$scanResult['safe'] && $scanResult['severity'] === 'reject') {
    Response::error("Content contains blocked terms: " . $scanResult['term'], 422);
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
            Security::sanitize($_POST['title']),
            Security::sanitize($_POST['description'] ?? ''),
            Security::sanitize($_POST['category'] ?? 'General'),
            $_POST['visibility'] ?? 'friends',
            $_POST['close_at'],
            isset($_POST['proof_required']) ? (int)$_POST['proof_required'] : 1
        ]
    );
    $betId = $db->lastInsertId();

    $outcomes = is_array($_POST['outcomes']) ? $_POST['outcomes'] : json_decode($_POST['outcomes'], true);
    if (count($outcomes) < 2) {
        throw new Exception("Minimum 2 outcomes required");
    }

    foreach ($outcomes as $index => $outcome) {
        $db->query(
            "INSERT INTO bet_outcomes (bet_id, label, coefficient, sort_order) VALUES (?, ?, ?, ?)",
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
        ["New bet pending review: " . Security::sanitize($_POST['title']), $betId]
    );

    $db->commit();
    Response::success(['bet_id' => (int)$betId], "Bet submitted for review");

} catch (Exception $e) {
    $db->rollBack();
    Response::error("Failed to create bet: " . $e->getMessage());
}
