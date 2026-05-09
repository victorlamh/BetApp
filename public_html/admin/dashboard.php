<?php
// admin/dashboard.php
// Note: In a production app, this would be protected by its own session.
// For v1, we will keep it simple and assume the user accessing it is the admin.

require_once __DIR__ . '/../api/bootstrap.php';
$db = DB::getInstance();

$pendingBets = $db->fetchAll(
    "SELECT b.*, u.username 
     FROM bets b 
     JOIN users u ON b.creator_user_id = u.id 
     WHERE b.status = 'pending_review' 
     ORDER BY b.created_at ASC"
);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bet App - Moderator Panel</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f0f12; color: white; padding: 40px; }
        .card { background: #1c1c21; padding: 20px; border-radius: 12px; margin-bottom: 20px; border: 1px solid #2d2d35; }
        .btn { padding: 10px 20px; border-radius: 8px; border: none; cursor: pointer; font-weight: bold; }
        .btn-approve { background: #ffcc00; color: black; }
        .btn-reject { background: #ff5252; color: white; margin-left: 10px; }
        h1 { color: #ffcc00; }
        .badge { background: #2d2d35; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Moderator Dashboard</h1>
    <p>Reviewing pending bets for <strong>inject.victorlamache.com</strong></p>

    <?php if (empty($pendingBets)): ?>
        <p>No bets currently pending review. Good job!</p>
    <?php endif; ?>

    <?php foreach ($pendingBets as $bet): ?>
        <div class="card">
            <h3><?php echo htmlspecialchars($bet['title']); ?></h3>
            <p><?php echo htmlspecialchars($bet['description']); ?></p>
            <p><small>Created by: <strong><?php echo htmlspecialchars($bet['username']); ?></strong> | Category: <?php echo htmlspecialchars($bet['category']); ?></small></p>
            
            <form action="action.php" method="POST">
                <input type="hidden" name="bet_id" value="<?php echo $bet['id']; ?>">
                <button type="submit" name="action" value="approve" class="btn btn-approve">APPROVE & PUBLISH</button>
                <button type="submit" name="action" value="reject" class="btn btn-reject">REJECT</button>
            </form>
        </div>
    <?php endforeach; ?>
</body>
</html>
