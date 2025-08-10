package com.example.demo.web;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.demo.domain.Owner;
import com.example.demo.service.OwnerService;

@RestController
@RequestMapping("/api/owners")
@CrossOrigin(origins = "*")
public class OwnerController {
    private final OwnerService ownerService;

    public OwnerController(OwnerService ownerService) {
        this.ownerService = ownerService;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> getOwners(@PageableDefault(size = 10) Pageable pageable) {
        Page<Owner> ownerPage = ownerService.getOwners(pageable);
        List<Map<String,Object>> owners = ownerPage.getContent().stream()
            .map(owner -> Map.<String,Object>of(
                "owner", owner,
                "_links", Map.of(
                    "self", "/api/owners/" + owner.getOwnerId()
                )
            ))
            .collect(Collectors.toList());
        Map<String, Object> response = new HashMap<>();
        response.put("_embedded", Map.of("owners", owners));
        response.put("_links", Map.of(
            "self", "/api/owners"
        ));
        Map<String, Object> pageInfo = new HashMap<>();
        pageInfo.put("size", ownerPage.getSize());
        pageInfo.put("totalElements", ownerPage.getTotalElements());
        pageInfo.put("totalPages", ownerPage.getTotalPages());
        pageInfo.put("number", ownerPage.getNumber());
        response.put("page", pageInfo);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String,Object>> getOwner(@PathVariable Long id) {
        Owner owner = ownerService.getOwner(id);
        Map<String,Object> body = Map.of(
            "owner", owner,
            "_links", Map.of(
                "self", "/api/owners/" + id,
                "collection", "/api/owners"
            )
        );
        return ResponseEntity.ok(body);
    }

    @PostMapping
    public Owner createOwner(@RequestBody Owner owner) {
        return ownerService.saveOwner(owner);
    }

    @DeleteMapping("/{id}")
    public void deleteOwner(@PathVariable Long id) {
        ownerService.deleteOwner(id);
    }
}