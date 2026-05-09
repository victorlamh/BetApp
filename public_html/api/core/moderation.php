<?php

class Moderation {
    public static function scan($text) {
        if (empty($text)) return ['safe' => true];

        $db = DB::getInstance();
        $terms = $db->fetchAll("SELECT * FROM blocked_terms WHERE is_active = 1");

        foreach ($terms as $term) {
            $pattern = '';
            if ($term['match_type'] === 'exact') {
                $pattern = '/\b' . preg_quote($term['term'], '/') . '\b/i';
            } elseif ($term['match_type'] === 'contains') {
                $pattern = '/' . preg_quote($term['term'], '/') . '/i';
            } elseif ($term['match_type'] === 'regex') {
                $pattern = '/' . $term['term'] . '/i';
            }

            if (preg_match($pattern, $text)) {
                return [
                    'safe' => false,
                    'term' => $term['term'],
                    'severity' => $term['severity']
                ];
            }
        }

        return ['safe' => true];
    }

    public static function checkDailyQuota($userId) {
        $db = DB::getInstance();
        $count = $db->fetchOne(
            "SELECT COUNT(*) as total FROM bets 
             WHERE creator_user_id = ? 
             AND created_at >= CURDATE() 
             AND status NOT IN ('draft', 'rejected')",
            [$userId]
        )['total'];

        return $count < 1;
    }
}
