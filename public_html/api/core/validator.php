<?php

class Validator {
    public static function validate($data, $rules) {
        $errors = [];
        foreach ($rules as $field => $fieldRules) {
            $value = $data[$field] ?? null;
            $fieldRulesArray = explode('|', $fieldRules);

            foreach ($fieldRulesArray as $rule) {
                if ($rule === 'required' && ($value === null || $value === '')) {
                    $errors[$field][] = "The $field field is required.";
                } elseif (strpos($rule, 'min:') === 0) {
                    $min = (int)substr($rule, 4);
                    if (strlen($value) < $min) {
                        $errors[$field][] = "The $field must be at least $min characters.";
                    }
                } elseif (strpos($rule, 'max:') === 0) {
                    $max = (int)substr($rule, 4);
                    if (strlen($value) > $max) {
                        $errors[$field][] = "The $field may not be greater than $max characters.";
                    }
                } elseif ($rule === 'email' && !filter_var($value, FILTER_VALIDATE_EMAIL)) {
                    $errors[$field][] = "The $field must be a valid email address.";
                } elseif ($rule === 'numeric' && !is_numeric($value)) {
                    $errors[$field][] = "The $field must be a number.";
                }
            }
        }

        if (!empty($errors)) {
            Response::error('Validation failed', 422, $errors);
        }

        return true;
    }
}
