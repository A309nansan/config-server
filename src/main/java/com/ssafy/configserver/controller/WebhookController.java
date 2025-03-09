package com.ssafy.configserver.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;

import java.util.Map;

@RestController
@RequestMapping("/webhook")
public class WebhookController {

    private final String BUS_REFRESH_URL = "http://localhost:8888/actuator/busrefresh";

    @Value("${spring.security.user.name}")
    private String USER;
    @Value("${spring.security.user.password}")
    private String PASSWORD;

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
        logger.info("Received Webhook");
        logger.info("Headers: {}", headers);
        logger.info("Payload: {}", payload);

        try {
            HttpHeaders httpHeaders = new HttpHeaders();
            httpHeaders.setBasicAuth(USER, PASSWORD);
            httpHeaders.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<String> entity = new HttpEntity<>(null, httpHeaders);

            ResponseEntity<Void> response = restTemplate.exchange(BUS_REFRESH_URL, HttpMethod.POST, entity, Void.class);

            if (response.getStatusCode().is2xxSuccessful()) {
                logger.info("✅ Success: triggered bus refresh!");
            } else {
                logger.warn("⚠️ Warning: Bus refresh triggered but received non-200 response: {}", response.getStatusCode());
            }
        } catch (Exception e) {
            logger.error("❌ Error: triggering bus refresh: {}", e.getMessage(), e);
        }
    }
}
