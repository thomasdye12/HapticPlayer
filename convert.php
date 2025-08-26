#!/usr/bin/env php
<?php
/**
 * Convert TSV/CSV lines like:
 * ID  haptics  HH:MM:SS.sss  index  intensity  duration
 * into an AHAP JSON file.
 *
 * Usage:
 *   php tsv_to_ahap.php input.tsv > pattern.ahap
 *   php tsv_to_ahap.php input.tsv output.ahap
 *   php tsv_to_ahap.php -  (reads stdin)
 *
 * Optional env:
 *   SHARPNESS=0.5 php tsv_to_ahap.php input.tsv > pattern.ahap
 */

$inPath  = $argv[1] ?? '-';
$outPath = $argv[2] ?? null;
$sharpness = isset($_ENV['SHARPNESS']) ? floatval($_ENV['SHARPNESS']) : 0.5;

function parseTimeToSeconds(string $ts): float {
    // Accept HH:MM:SS(.sss)
    $parts = explode(':', trim($ts));
    if (count($parts) !== 3) return 0.0;
    [$hh, $mm, $ss] = $parts;
    return intval($hh) * 3600 + intval($mm) * 60 + floatval($ss);
}

function clamp01($v) { return max(0.0, min(1.0, floatval($v))); }

$fh = $inPath === '-' ? fopen("php://stdin", "r") : @fopen($inPath, "r");
if (!$fh) {
    fwrite(STDERR, "Failed to open input: $inPath\n");
    exit(1);
}

$pattern = [];

while (($line = fgets($fh)) !== false) {
    $line = trim($line);
    if ($line === '' || $line[0] === '#') continue;

    // Split on tabs or commas (tolerates multiple)
    $cols = preg_split('/[,\t]+/', $line);

    if (count($cols) < 6) {
        // Skip lines that don't match expected format
        continue;
    }

    // Expected columns:
    // 0: id, 1: "haptics", 2: time, 3: index, 4: intensity, 5: duration
    $time       = parseTimeToSeconds($cols[2]);
    $intensity  = clamp01($cols[4]);
    $duration   = max(0.0, floatval($cols[5]));

    $pattern[] = [
        "Event" => [
            "EventType"      => "HapticContinuous",
            "Time"           => $time,
            "EventDuration"  => $duration,
            "EventParameters"=> [
                ["ParameterID" => "HapticIntensity", "ParameterValue" => $intensity],
                ["ParameterID" => "HapticSharpness", "ParameterValue" => $sharpness],
            ],
        ],
    ];
}
fclose($fh);

$ahap = ["Version" => 1, "Pattern" => array_values($pattern)];
$json = json_encode($ahap, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);

if ($outPath) {
    if (@file_put_contents($outPath, $json) === false) {
        fwrite(STDERR, "Failed to write output: $outPath\n");
        exit(1);
    }
} else {
    echo $json, PHP_EOL;
}
