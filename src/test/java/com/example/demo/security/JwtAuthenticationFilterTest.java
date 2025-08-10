package com.example.demo.security;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.demo.domain.User;
import com.example.demo.repository.UserRepository;

@SpringBootTest
@AutoConfigureMockMvc
class JwtAuthenticationFilterTest {
    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder encoder;
    @Autowired JwtTokenUtil jwtTokenUtil;

    @Test
    @org.springframework.transaction.annotation.Transactional
    void accessProtectedWithValidToken() throws Exception {
    String username = "jwtuser_" + System.currentTimeMillis();
    userRepository.save(new User(null, username, encoder.encode("jwtpass"), "ROLE_USER"));
    String token = jwtTokenUtil.generateToken(username);
    mockMvc.perform(get("/api/cars")
        .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk());
    }

    @Test
    void accessProtectedWithInvalidToken() throws Exception {
        mockMvc.perform(get("/api/cars")
                .header("Authorization", "Bearer badtoken"))
                .andExpect(status().isUnauthorized());
    }
}
