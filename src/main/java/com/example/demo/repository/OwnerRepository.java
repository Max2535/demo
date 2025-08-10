package com.example.demo.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.demo.domain.Owner;

public interface OwnerRepository extends JpaRepository<Owner, Long> {
}