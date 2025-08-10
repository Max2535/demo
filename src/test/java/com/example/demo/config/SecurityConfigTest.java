package com.example.demo.config;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.AuthenticationManager;

@SpringBootTest
class SecurityConfigTest {
    @Autowired AuthenticationManager authenticationManager;

    @Test
    void authenticationManagerLoads() {
        assertThat(authenticationManager).isNotNull();
    }
}
