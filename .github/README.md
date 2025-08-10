# GitHub Actions CI/CD Workflow Documentation

This repository includes a comprehensive CI/CD pipeline with multiple GitHub Actions workflows for different purposes.

## Workflows Overview

### 1. Main CI/CD Pipeline (`ci-cd.yml`)
**Triggers:** Push to main/develop, Pull requests to main, Manual dispatch

**Jobs:**
- **Code Quality & Security Analysis**
  - Checkstyle code style checking
  - SpotBugs static analysis
  - OWASP dependency vulnerability scanning
  
- **Tests**
  - Unit tests with MariaDB service
  - Integration tests
  - Code coverage reporting with Codecov
  - Test result reporting
  
- **Build Application**
  - Maven build and packaging
  - Version extraction
  - Artifact upload
  
- **Docker Build & Security Scan**
  - Docker image build and push to GitHub Container Registry
  - Trivy security scanning
  - SARIF upload to GitHub Security tab
  
- **Deploy to Staging** (develop branch)
  - Automated staging deployment
  
- **Deploy to Production** (main branch)
  - Production deployment with environment protection
  
- **Notifications**
  - Success/failure notifications

### 2. Security Scan (`security-scan.yml`)
**Triggers:** Weekly schedule (Monday 2 AM), Manual dispatch

**Features:**
- OWASP dependency check
- Snyk vulnerability scanning
- Automatic security issue creation on vulnerabilities
- Security report artifacts

### 3. Performance Testing (`performance-test.yml`)
**Triggers:** Push to main, Weekly schedule (Monday 3 AM), Manual dispatch

**Features:**
- Apache Bench load testing
- API endpoint performance testing
- Performance report generation
- Automatic application startup/shutdown

### 4. Release Management (`release.yml`)
**Triggers:** Version tags (v*), Manual dispatch with version input

**Features:**
- Automated release creation
- Version management in pom.xml
- Changelog generation
- Docker image tagging
- GitHub release with artifacts
- Production deployment

### 5. Dependency Updates (`dependency-update.yml`)
**Triggers:** Weekly schedule (Monday 4 AM), Manual dispatch

**Features:**
- Automated Maven dependency updates
- GitHub Actions version updates
- Automatic Pull Request creation
- Test validation before PR creation

## Setup Instructions

### 1. Repository Secrets
Add these secrets to your GitHub repository:

```
SNYK_TOKEN          # Snyk API token for vulnerability scanning
DATABASE_URL        # Production database URL
DATABASE_USERNAME   # Production database username
DATABASE_PASSWORD   # Production database password
JWT_SECRET          # Production JWT secret key
```

### 2. Environment Configuration
Configure GitHub environments:

**staging:**
- Protection rules: Required reviewers (optional)
- Environment secrets if different from repository

**production:**
- Protection rules: Required reviewers
- Branch restrictions: main branch only
- Environment-specific secrets

### 3. Repository Settings
Enable these repository features:
- Actions permissions: Allow all actions
- Security: Dependency graph, Dependabot alerts
- Code scanning: Enable CodeQL analysis

### 4. Branch Protection
Configure branch protection for `main`:
- Require pull request reviews
- Require status checks to pass before merging
- Require branches to be up to date before merging
- Include administrators

## Docker Support

### Development
```bash
# Build and run locally
docker-compose -f docker-compose.dev.yml up --build

# Run with pre-built image
docker-compose up
```

### Production
```bash
# Pull and run production image
docker pull ghcr.io/max2535/demo:latest
docker-compose -f docker-compose.yml up
```

## Local Development

### Prerequisites
- Java 17
- Maven 3.6+
- MariaDB 11.3+
- Docker & Docker Compose

### Running Tests
```bash
# Unit tests
./mvnw test

# Integration tests
./mvnw verify

# With coverage
./mvnw test jacoco:report
```

### Code Quality
```bash
# Checkstyle
./mvnw checkstyle:checkstyle

# SpotBugs
./mvnw compile spotbugs:spotbugs

# OWASP dependency check
./mvnw org.owasp:dependency-check-maven:check
```

## Monitoring & Observability

### Health Checks
- Application: `/actuator/health`
- Database: MariaDB health check
- Docker: Container health checks

### Metrics
- Prometheus metrics: `/actuator/prometheus`
- Application metrics: `/actuator/metrics`
- Custom business metrics available

### Logging
- Structured logging with Logback
- Different log levels per environment
- Log aggregation ready

## Security Features

### Application Security
- JWT-based authentication
- Role-based authorization
- CORS configuration
- Security headers
- Input validation

### CI/CD Security
- Dependency vulnerability scanning
- Container image scanning
- Security issue tracking
- Automated security updates
- Secret management

## Performance

### Optimization
- JVM tuning for containers
- Database connection pooling
- HTTP/2 support
- Response compression
- Caching strategies

### Monitoring
- Performance testing in CI
- Load testing with Apache Bench
- Database query optimization
- Memory and CPU profiling

## Deployment Strategies

### Blue-Green Deployment
Ready for blue-green deployment with:
- Health checks
- Graceful shutdown
- Zero-downtime deployments

### Rolling Updates
Supports rolling updates with:
- Kubernetes readiness probes
- Docker health checks
- Load balancer integration

## Troubleshooting

### Common Issues
1. **Build Failures**
   - Check Java version compatibility
   - Verify Maven dependencies
   - Review test database connectivity

2. **Security Scan Failures**
   - Update vulnerable dependencies
   - Review security advisories
   - Check CVE database

3. **Deployment Issues**
   - Verify environment secrets
   - Check resource availability
   - Review deployment logs

### Debug Mode
Enable debug logging:
```yaml
logging.level.com.example.demo=DEBUG
logging.level.org.springframework.security=DEBUG
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run quality checks locally
5. Submit a pull request
6. Wait for CI/CD validation
7. Address review feedback

## License

This project is licensed under the MIT License - see the LICENSE file for details.
