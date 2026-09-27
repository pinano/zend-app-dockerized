<?php
/**
 * Zend_Log Writer that outputs structured JSON lines to STDERR.
 *
 * Designed for Docker + Grafana Alloy / Loki ingestion.
 * Each log entry becomes a single JSON line with predictable fields,
 * avoiding the need for complex regex parsing in the log pipeline.
 *
 * Usage in application.ini:
 *   resources.logger.writerName = "StderrJson"
 *
 * If the class is not autoloaded by your ZF1 setup, require it manually
 * in public/index.php before bootstrapping:
 *   require_once 'Log/Writer/StderrJson.php';
 *
 * Place this file in: library/Log/Writer/StderrJson.php
 */
class Log_Writer_StderrJson extends Zend_Log_Writer_Abstract
{
    /**
     * @var array Static fields merged into every log entry.
     */
    protected $_extras = [];

    /**
     * Constructor.
     *
     * @param array|string $config Unused, kept for Zend_Log compatibility.
     */
    public function __construct($config = null)
    {
        if (is_array($config)) {
            // Allow injecting static metadata via factory/config
            if (isset($config['extras']) && is_array($config['extras'])) {
                $this->_extras = $config['extras'];
            }
        }
    }

    /**
     * Factory method for Zend_Log adapter integration.
     *
     * @param array $config
     * @return Log_Writer_StderrJson
     */
    static public function factory($config)
    {
        return new self($config);
    }

    /**
     * Write a log event to STDERR as JSON.
     *
     * @param array $event Standard Zend_Log event array.
     * @return void
     */
    protected function _write($event)
    {
        $data = [
            'time'    => date('c', isset($event['timestamp']) ? $event['timestamp'] : time()),
            'level'   => isset($event['priorityName']) ? $event['priorityName'] : 'UNKNOWN',
            'message' => isset($event['message']) ? $event['message'] : '',
            'logger'  => 'zend',
        ];

        // Merge any extras set via Zend_Log::setEventItem() or passed through ErrorController
        if (!empty($event) && is_array($event)) {
            $excludedKeys = ['message', 'priority', 'priorityName', 'timestamp'];
            foreach ($event as $key => $value) {
                if (!in_array($key, $excludedKeys, true)) {
                    $data[$key] = $value;
                }
            }
        }

        // Merge static extras configured at construction time
        if (!empty($this->_extras)) {
            $data = array_merge($data, $this->_extras);
        }

        // Encode as compact JSON line. Suppress encoding errors for robustness.
        $json = @json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        if ($json === false) {
            $json = json_encode([
                'time'    => date('c'),
                'level'   => 'ERROR',
                'message' => 'Log entry JSON encoding failed: ' . json_last_error_msg(),
                'logger'  => 'zend',
            ], JSON_UNESCAPED_SLASHES);
        }

        $line = $json . "\n";

        // STDERR in PHP-FPM is connected to Docker container logs thanks to
        // catch_workers_output=yes in zz-docker.conf.
        if (defined('STDERR') && is_resource(STDERR)) {
            fwrite(STDERR, $line);
        } else {
            // Fallback: error_log() also reaches Docker logs via FPM.
            error_log(rtrim($line));
        }
    }
}
