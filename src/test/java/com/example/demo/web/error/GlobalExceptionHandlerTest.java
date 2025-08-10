package com.example.demo.web.error;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class GlobalExceptionHandlerTest {
    @Autowired MockMvc mockMvc;

    @Autowired com.example.demo.repository.UserRepository userRepository;
    @Autowired com.example.demo.security.JwtTokenUtil jwtTokenUtil;

    @Test
    @org.springframework.transaction.annotation.Transactional
    void notFoundExceptionHandled() throws Exception {
        userRepository.deleteByUsername("erruser");
        userRepository.save(new com.example.demo.domain.User(null, "erruser", "{noop}errpass", "ROLE_USER"));
        String jwtToken = jwtTokenUtil.generateToken("erruser");
        mockMvc.perform(get("/api/cars/99999")
                .header("Authorization", "Bearer " + jwtToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("not_found"));
    }
}
