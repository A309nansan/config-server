package com.ssafy.configserver.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/webhook")
public class WebhookController {

    private final String BUS_REFRESH_URL = "http://localhost:8888/actuator/busrefresh";

    private static final Logger logger = LoggerFactory.getLogger(WebhookController.class);
    private final RestTemplate restTemplate;

    public WebhookController(RestTemplateBuilder builder) {
        this.restTemplate = builder.build();
    }

    @PostMapping
    public void  proxy(
            @RequestHeader Map<String, String> headers,
            @RequestBody(required = false) Map<String, Object> payload
    ) {

        // Webhook Request Logging
        logger.info("🔔 Received Webhook");
        logger.info("📌 Headers: {}", headers);
        logger.info("📌 Payload: {}", payload);

        try {
            restTemplate.postForObject(BUS_REFRESH_URL, null, Void.class);
            logger.info("Success: triggered bus refresh!");
        } catch (Exception e) {
            logger.error("Error: triggering bus refresh: {}", e.getMessage(), e);
        }
    }
}
