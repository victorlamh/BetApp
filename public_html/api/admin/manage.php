<?php
require_once __DIR__ . '/../bootstrap.php';

// Ensure user is admin
Auth::requireRole('admin');

$action = $_POST['action'] ?? ''; 
$targetId = (int)($_POST['user_id'] ?? 0);

if (!$targetId) {
    Response::error("Target user ID required");
}

$db = DB::getInstance();

switch ($action) {
    case 'update_balance':
        $amount = (float)($_POST['amount'] ?? 0);
        $reason = Security::sanitize($_POST['reason'] ?? 'Admin adjustment');
        
        try {
            $db->beginTransaction();
            
            // Get current balance
            $wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ?", [$targetId]);
            if (!$wallet) throw new Exception("User wallet not found");
            
            $newBalance = $wallet['balance'] + $amount;
            
            $db->query("UPDATE wallets SET balance = ? WHERE user_id = ?", [$newBalance, $targetId]);
            
            $db->query(
                "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, notes) 
                 VALUES (?, 'admin_adjustment', ?, ?, ?, ?)",
                [$targetId, $amount, $wallet['balance'], $newBalance, $reason]
            );
            
            $db->query(
                "INSERT INTO notifications (user_id, type, message) VALUES (?, 'balance_update', ?)",
                [$targetId, "Admin adjusted your balance by " . number_format($amount, 2) . "€. Reason: $reason"]
            );
            
            $db->commit();
            Response::success(['new_balance' => $newBalance], "Balance updated successfully");
        } catch (Exception $e) {
            $db->rollBack();
            Response::error($e->getMessage());
        }
        break;

    case 'ban_user':
        $db->query("UPDATE users SET status = 'banned' WHERE id = ?", [$targetId]);
        Response::success(null, "User banned");
        break;

    case 'unban_user':
        $db->query("UPDATE users SET status = 'active' WHERE id = ?", [$targetId]);
        Response::success(null, "User unbanned");
        break;

    default:
        Response::error("Invalid admin action");
}
