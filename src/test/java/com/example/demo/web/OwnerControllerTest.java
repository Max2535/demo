package com.example.demo.web;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.demo.domain.Owner;
import com.example.demo.repository.OwnerRepository;

@SpringBootTest
@AutoConfigureMockMvc
class OwnerControllerTest {
    @Autowired MockMvc mockMvc;
    @Autowired OwnerRepository ownerRepository;

    @Autowired com.example.demo.repository.UserRepository userRepository;
    @Autowired com.example.demo.security.JwtTokenUtil jwtTokenUtil;

    String jwtToken;

    @BeforeEach
    @org.springframework.transaction.annotation.Transactional
    void setup() {
        ownerRepository.deleteAll();
        userRepository.deleteByUsername("owneruser");
        userRepository.save(new com.example.demo.domain.User(null, "owneruser", "{noop}ownerpass", "ROLE_USER"));
        jwtToken = jwtTokenUtil.generateToken("owneruser");
        ownerRepository.save(new Owner(null, "Jane", "Smith", List.of()));
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void getOwnersPaged() throws Exception {
    mockMvc.perform(get("/api/owners?page=0&size=5")
        .header("Authorization", "Bearer " + jwtToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.page.size").value(5));
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void getOwnerById() throws Exception {
    Owner owner = ownerRepository.findAll().get(0);
    mockMvc.perform(get("/api/owners/" + owner.getOwnerId())
        .header("Authorization", "Bearer " + jwtToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.owner.firstName").value("Jane"))
        .andExpect(jsonPath("$.owner.lastName").value("Smith"));
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void createOwner() throws Exception {
    mockMvc.perform(post("/api/owners")
        .header("Authorization", "Bearer " + jwtToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content("{" +
            "\"firstName\":\"Sam\"," +
            "\"lastName\":\"Wilson\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.firstName").value("Sam"));
    }
}
