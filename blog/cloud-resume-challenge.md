# How I Built My Cloud Resume on AWS

The **AWS Cloud Resume Challenge** is a hands-on project that pushes you to build a full-stack application using real AWS services. Here's how I approached it and what I learned along the way.

## The Goal

Build a personal resume website that's not just a static page — it needs to be a production-grade, serverless application with a custom domain, HTTPS, a backend API, a database, Infrastructure as Code, and CI/CD.

## Architecture Overview

The site uses a fully serverless architecture on AWS:

- **S3** hosts the static files (HTML, CSS, JS, images)
- **CloudFront** serves them globally with HTTPS
- **Route 53** manages the custom domain
- **ACM** provides the TLS certificate
- **API Gateway** exposes a REST endpoint
- **Lambda** (Python) handles the visitor counter logic
- **DynamoDB** stores the visitor count
- **CloudFormation** defines the entire infrastructure as code
- **GitHub Actions** automates deployments on every push

## The Frontend

I kept it simple — vanilla HTML, CSS, and JavaScript with tab-based navigation. No frameworks, no build tools. The site has four tabs: Home, Resume, Projects, and Certifications.

The visitor counter on the homepage makes a `fetch` call to `/api/counter`, which CloudFront routes to API Gateway.

## The Backend

The Lambda function is straightforward — it uses DynamoDB's `UpdateItem` with an atomic `ADD` operation to increment the visitor count. This avoids race conditions even under concurrent requests.

```python
response = table.update_item(
    Key={'id': 'visitors'},
    UpdateExpression='ADD visit_count :inc',
    ExpressionAttributeValues={':inc': 1},
    ReturnValues='UPDATED_NEW'
)
```

## Infrastructure as Code

Everything is defined in a single CloudFormation template. One command creates the entire stack — S3 bucket, CloudFront distribution, ACM certificate, Route 53 records, DynamoDB table, Lambda function, API Gateway, and all the IAM roles.

This was one of the most valuable parts of the challenge. Writing CloudFormation forces you to understand how every service connects and what permissions are needed.

## CI/CD Pipeline

I set up GitHub Actions to automatically deploy website changes. Every push to `main` triggers a pipeline that syncs files to S3 and invalidates the CloudFront cache. No more manual deployments.

## Key Takeaways

1. **CloudFront OAC over OAI** — Origin Access Control is the modern, more secure way to connect CloudFront to S3
2. **Least privilege IAM** — Every role and policy should grant only the minimum permissions needed
3. **Atomic database operations** — DynamoDB's `ADD` expression handles concurrency without locks
4. **Infrastructure as Code is essential** — Manual console clicks don't scale and can't be version-controlled
5. **CI/CD changes everything** — Automating deployments removes friction and reduces errors

## What's Next

I'm planning to add visitor analytics, a dark mode toggle, and a contact form powered by SES. The foundation is solid — adding features on top of a well-architected stack is the fun part.

---

*This post is part of my journey through the AWS Cloud Resume Challenge. Feel free to check out the [project on GitHub](https://github.com/josephnaja/aws-cloud-resume) or visit the live site at [josephnaja.com](https://josephnaja.com).*
