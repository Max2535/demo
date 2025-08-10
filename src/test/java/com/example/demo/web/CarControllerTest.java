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

import com.example.demo.domain.Car;
import com.example.demo.domain.Owner;
import com.example.demo.repository.CarRepository;
import com.example.demo.repository.OwnerRepository;

@SpringBootTest
@AutoConfigureMockMvc
class CarControllerTest {
    @Autowired MockMvc mockMvc;
    @Autowired CarRepository carRepository;
    @Autowired OwnerRepository ownerRepository;

    @Autowired com.example.demo.repository.UserRepository userRepository;
    @Autowired com.example.demo.security.JwtTokenUtil jwtTokenUtil;

    String jwtToken;

    @BeforeEach
    @org.springframework.transaction.annotation.Transactional
    void setup() {
        carRepository.deleteAll();
        ownerRepository.deleteAll();
        userRepository.deleteByUsername("caruser");
        userRepository.save(new com.example.demo.domain.User(null, "caruser", "{noop}carpass", "ROLE_USER"));
        jwtToken = jwtTokenUtil.generateToken("caruser");
        Owner owner = ownerRepository.save(new Owner(null, "John", "Doe", List.of()));
        carRepository.save(new Car(null, "Toyota", "Corolla", 2020, owner));
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void getCarsPaged() throws Exception {
    mockMvc.perform(get("/api/cars?page=0&size=5")
        .header("Authorization", "Bearer " + jwtToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.size").value(5))
        .andExpect(jsonPath("$.content[0].brand").value("Toyota"));
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void getCarById() throws Exception {
    Car car = carRepository.findAll().get(0);
    mockMvc.perform(get("/api/cars/" + car.getCarId())
        .header("Authorization", "Bearer " + jwtToken))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.brand").value("Toyota"));
    }

    @Test
    @org.springframework.transaction.annotation.Transactional
    void createCar() throws Exception {
    Owner owner = ownerRepository.findAll().get(0);
    mockMvc.perform(post("/api/cars")
        .header("Authorization", "Bearer " + jwtToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content("{" +
            "\"brand\":\"Honda\"," +
            "\"model\":\"Civic\"," +
            "\"year\":2021," +
            "\"owner\":{" +
            "\"ownerId\":" + owner.getOwnerId() + "}" +
            "}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.brand").value("Honda"));
    }
}
