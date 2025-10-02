<?php
$host = "mysql-openemr-dev-uksouth.mysql.data";
$user = "openemradmin";
$pass = "XNRMrnS0DHta9SKpL0PpPA9EVRm8xX29T2E0YivOg";
$db = "openemr";

$conn = new mysqli($host, $user, $pass, $db, 3306);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
} else {
    echo "Connected successfully!";
}
?>