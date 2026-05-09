<?php
// Environment Configuration Template
// Rename this to env.php on your server

return [
    'db' => [
        'host' => 'db5020419791.hosting-data.io',
        'name' => 'dbs15654071',
        'user' => 'dbu3778519',
        'pass' => 'poiuytrezaM1.',
        'charset' => 'utf8mb4',
    ],
    'app' => [
        'url' => 'https://inject.victorlamache.com/api',
        'debug' => false,
        'timezone' => 'UTC',
    ],
    'auth' => [
        'token_expiry_days' => 30,
        'secret_key' => '8f2d6e4b9c1a5d7f3e0b2c4a6d8f1e3b5c7a9d0e2f4b6c8a0d2f4e6b8c0a',
    ],
    'security' => [
        'allowed_origins' => ['*'], // Update this for production
    ],
];
