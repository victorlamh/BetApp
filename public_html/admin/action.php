<?php
// admin/action.php
require_once __DIR__ . '/../api/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    die("Invalid request");
}

$betId = (int)$_POST['bet_id'];
$action = $_POST['action'];
$db = DB::getInstance();

try {
    $db->beginTransaction();

    if ($action === 'approve') {
        // Set to live and update published dates
        $db->query(
            "UPDATE bets SET status = 'live', approved_at = NOW(), published_at = NOW() WHERE id = ?",
            [$betId]
        );
        $message = "Bet #$betId approved!";
    } elseif ($action === 'reject') {
        $db->query("UPDATE bets SET status = 'rejected' WHERE id = ?", [$betId]);
        $message = "Bet #$betId rejected!";
    }

    $db->commit();
    echo "<script>alert('$message'); window.location.href='dashboard.php';</script>";

} catch (Exception $e) {
    $db->rollBack();
    die("Error: " . $e->getMessage());
}
