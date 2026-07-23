<?php
// CORS-Regeln für deinen Browser
//
// WICHTIG: Diese Datei ist nur eine VORLAGE.
// 1. Kopiere sie zu "cors.php"
// 2. Trage unten bei $allowedOrigins deine eigene Domain ein
// 3. Lade NUR "cors.php" auf deinen Webspace hoch (nicht diese Beispiel-Datei)
//    "cors.php" landet nicht im Git-Repo (siehe .gitignore), damit deine
//    eigene Domain nicht öffentlich sichtbar ist.

// Trage hier die Domain(s) ein, von denen aus deine PWA läuft.
// "www." wird automatisch mit erkannt, du musst es nicht doppelt eintragen.
$allowedOrigins = [
    'deine-domain.de',
];

$requestOrigin = $_SERVER['HTTP_ORIGIN'] ?? '';
$requestHost = parse_url($requestOrigin, PHP_URL_HOST) ?? '';
$normalizedHost = preg_replace('/^www\./i', '', $requestHost);

$isAllowed = false;
foreach ($allowedOrigins as $allowed) {
    if (strcasecmp($normalizedHost, preg_replace('/^www\./i', '', $allowed)) === 0) {
        $isAllowed = true;
        break;
    }
}

if ($isAllowed && $requestOrigin !== '') {
    header("Access-Control-Allow-Origin: $requestOrigin");
}

header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PROPFIND, REPORT, MKCOL");
header("Access-Control-Allow-Headers: Authorization, Content-Type, Depth, GROCY-API-KEY, X-HTTP-Method-Override");
header("Access-Control-Allow-Credentials: true");

// Den fehlerhaften Ping (Preflight) fangen wir hier ab!
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(204);
    exit;
}

if (!function_exists('getallheaders')) {
    function getallheaders() {
        $headers = [];
        foreach ($_SERVER as $name => $value) {
            if (substr($name, 0, 5) == 'HTTP_') {
                $headers[str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($name, 5)))))] = $value;
            } else if ($name == "CONTENT_TYPE") {
                $headers["Content-Type"] = $value;
            } else if ($name == "CONTENT_LENGTH") {
                $headers["Content-Length"] = $value;
            }
        }
        return $headers;
    }
}

$targetUrl = $_GET['target'] ?? '';
if (empty($targetUrl)) {
    http_response_code(400);
    die("Tunnel-Fehler: Kein Ziel angegeben.");
}

$params = $_GET;
unset($params['target']);
if (!empty($params)) {
    $targetUrl .= (strpos($targetUrl, '?') === false ? '?' : '&') . http_build_query($params, '', '&', PHP_QUERY_RFC3986);
}

// Original-Header der App auslesen und Maskierung (Override) prüfen
$headers = [];
$realMethod = $_SERVER['REQUEST_METHOD'];

foreach (getallheaders() as $name => $value) {
    $lowerName = strtolower($name);
    // Maske abnehmen!
    if ($lowerName === 'x-http-method-override') {
        $realMethod = strtoupper($value);
    }
    if (in_array($lowerName, ['host', 'origin', 'referer', 'content-length', 'accept-encoding'])) continue;
    $headers[] = "$name: $value";
}

$body = file_get_contents('php://input');

// ==========================================
// FIX: Manueller Umleitungs-Loop (verhindert Ausbrechen des Browsers)
// ==========================================
$maxRedirects = 3;
for ($i = 0; $i < $maxRedirects; $i++) {
    $ch = curl_init($targetUrl);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $realMethod);
    if (!empty($body)) curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HEADER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    $responseHeaders = substr($response, 0, $headerSize);
    $responseBody = substr($response, $headerSize);
    curl_close($ch);

    // Umleitung abfangen, BEVOR der Browser sie sieht!
    if (in_array($httpCode, [301, 302, 307, 308]) && preg_match('/^Location:\s*(.+)$/mi', $responseHeaders, $matches)) {
        $redirectUrl = trim($matches[1]);
        if (strpos($redirectUrl, 'http') !== 0) {
            $parsedTarget = parse_url($targetUrl);
            $targetUrl = $parsedTarget['scheme'] . '://' . $parsedTarget['host'] . $redirectUrl;
        } else {
            $targetUrl = $redirectUrl;
        }
        continue; // Starte cURL nochmal mit dem neuen Ziel!
    }
    break; // Keine Umleitung -> Wir haben das echte Ziel erreicht.
}

// Header an App weitergeben
foreach (explode("\r\n", $responseHeaders) as $hdr) {
    if (stripos($hdr, 'Access-Control') === 0 || empty($hdr)) continue;
    if (stripos($hdr, 'Transfer-Encoding') === 0) continue;
    // WICHTIG: Location darf niemals an den Browser geschickt werden!
    if (stripos($hdr, 'Location:') === 0) continue;
    header($hdr);
}

http_response_code($httpCode);
echo $responseBody;
