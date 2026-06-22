<?php

echo "Hello World!";

$serverName = getenv('SQL_SERVER_NAME'); // Get server name from environment variables
$connectionOptions = array(
    "Database" => getenv('SQL_DATABASE_NAME'), // Get database name from environment variables
    "Uid" => getenv('SQL_UID'),               // Get username from environment variables
    "PWD" => getenv('SQL_PWD')                // Get password from environment variables
);

try {
    $conn = new PDO("sqlsrv:server=$serverName;Database=".$connectionOptions['Database'], $connectionOptions['Uid'], $connectionOptions['PWD']);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "Connected!";
} catch (PDOException $e) {
    echo "Connection failed: " . $e->getMessage();
}