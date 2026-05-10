<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireRole(['admin', 'moderator']);

Validator::validate($_POST, [
    'bet_id' => 'required|numeric',
    'action' => 'required|string', // 'delete', 'void'
    'reason' => 'string'
]);

$betId = (int)$_POST['bet_id'];
$action = $_POST['action'];
$reason = $_POST['reason'] ?? 'Admin action';
$db = DB::getInstance();

try {
    $db->beginTransaction();

    $bet = $db->fetchOne("SELECT status FROM bets WHERE id = ? FOR UPDATE", [$betId]);
    if (!$bet) throw new Exception("Bet not found");

    if ($action === 'delete') {
        // Refund all wagers
        $wagers = $db->fetchAll("SELECT * FROM wagers WHERE bet_id = ? AND status = 'active'", [$betId]);
        foreach ($wagers as $wager) {
            $userId = $wager['user_id'];
            $stake = (float)$wager['stake'];
            
            // Lock wallet
            $wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE", [$userId]);
            $newBalance = $wallet['balance'] + $stake;
            
            $db->query("UPDATE wallets SET balance = ? WHERE user_id = ?", [$newBalance, $userId]);
            $db->query(
                "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, bet_id, notes) 
                 VALUES (?, 'void_refund', ?, ?, ?, ?, ?)",
                [$userId, $stake, $wallet['balance'], $newBalance, $betId, "Refund for deleted bet #$betId: $reason"]
            );
        }
        
        $db->query("DELETE FROM bets WHERE id = ?", [$betId]);
        $message = "Bet deleted and all wagers refunded.";
        
    } elseif ($action === 'void') {
        // Mark as void and refund
        $wagers = $db->fetchAll("SELECT * FROM wagers WHERE bet_id = ? AND status = 'active'", [$betId]);
        foreach ($wagers as $wager) {
            $userId = $wager['user_id'];
            $stake = (float)$wager['stake'];
            
            $wallet = $db->fetchOne("SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE", [$userId]);
            $newBalance = $wallet['balance'] + $stake;
            
            $db->query("UPDATE wallets SET balance = ? WHERE user_id = ?", [$newBalance, $userId]);
            $db->query(
                "INSERT INTO wallet_ledger (user_id, entry_type, amount, balance_before, balance_after, bet_id, notes) 
                 VALUES (?, 'void_refund', ?, ?, ?, ?, ?)",
                [$userId, $stake, $wallet['balance'], $newBalance, $betId, "Refund for voided bet #$betId: $reason"]
            );
        }
        
        $db->query("UPDATE wagers SET status = 'void' WHERE bet_id = ?", [$betId]);
        $db->query("UPDATE bets SET status = 'void', void_reason = ? WHERE id = ?", [$reason, $betId]);
        $message = "Bet voided and all wagers refunded.";
    } elseif ($action === 'lock') {
        $db->query("UPDATE bets SET status = 'locked', close_at = NOW() WHERE id = ?", [$betId]);
        $message = "Bet closed for wagering.";
    }

    $db->commit();
    Response::success(null, $message);

} catch (Exception $e) {
    $db->rollBack();
    Response::error($e->getMessage());
}
