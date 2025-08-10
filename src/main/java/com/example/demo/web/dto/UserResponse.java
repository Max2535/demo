package com.example.demo.web.dto;

// สำหรับส่งกลับไปยัง client
public record UserResponse(
        Long id, String firstName, String lastName, String email
) {}
