# Azure API Center

In today’s API-first digital ecosystem, organizations are challenged with an ever-expanding network of APIs. This proliferation - known as API sprawl - poses significant challenges in API governance, security, compliance, and reuse. Without a centralized inventory, APIs can become isolated, leading to poor API reuse, lack of alignment with organizational API design and organizational processes, as well as increased vulnerability to security breaches.

## Content Overview

- :bulb: [What is Azure API Center?](#azure-api-center)
- :arrow_forward: [Getting Started Resources](#getting-started-resources)
- :dart: [Roadmap](#roadmap)
- :warning: [How to provide feedback](#how-to-provide-feedback)
- :bookmark_tabs: [Other resources](#other-resources)

## What is Azure API Center?

**Azure API Center** provides a centralized API inventory for seamless API discovery, reuse, and governance regardless of API type, lifecycle stage, or deployment location. Azure API Center addresses a critical need for centralized API inventory, ensuring that the extraordinary growth of APIs enhances rather than hinders the development process:

- **Build a complete and current catalog of all APIs** - regardless of their type, stage in their lifecycle, or deployment location - to enable API discovery, consumption, and governance.

- Enable API best practices at-scale and **enforce API design rules** across your organization to empower API developers to create APIs in line with these standards, ensuring quality and uniformity across all APIs produced.

- **Foster reusability** of your APIs by enabling API consumers to quickly discover and consume the right APIs.

- **Improve API producer and consumer developer experience** with our Visual Studio Code extension.

[Learn more about API Center](https://aka.ms/apicenter/blogpost)


![APIs view in Azure API Center](media/readme-screenshot.png)

## Getting Started Resources

**What is Azure API Center?**
- Video: [Exploring Azure API Center: From VS Code to the Azure Portal](https://youtu.be/w9Sr7adTPPI?si=s-vWG5VBKETuxD5X)
- Blog: [Navigating Your API Ecosystem - Example Scenarios for Azure API Center and API Management](https://techcommunity.microsoft.com/t5/azure-integration-services-blog/the-rising-significance-of-apis-azure-api-management-amp-api/ba-p/4181292)

**Build a Complete & Current API Inventory:**
- Quickstart: [Create your API center](https://learn.microsoft.com/azure/api-center/set-up-api-center)
- Video: [Automate API Registration with GitHub Actions in Azure API Center](https://youtu.be/DviYjNVJ-cw?si=h0EBUWEh3uuMDgOL)
- Tutorial: [Integrate APIs from Azure API Management](https://learn.microsoft.com/azure/api-center/synchronize-api-management-apis)
- Video: [Integrate APIs from Amazon API Gateway](https://youtu.be/9vhGOxKD2ME?si=0fcQyJb47L933JNb)
- Tutorial: [Register APIs in your API inventory](https://learn.microsoft.com/azure/api-center/register-apis)

**API Governance - Design time governance:**
- Video: [Mastering API Governance with Azure API Center](https://youtu.be/m0XATQaVhxA?si=oDfFDPE9hDPbrczP)
- Video: [API design-first with Azure API Center and GitHub Copilot for Azure](https://youtu.be/MSYS4bLYews?si=3PFAZnwA1rKYwLa-)
- Unlock the Future of API Compliance with AI and Azure API Center:
    - [Video](https://youtu.be/G-3Jdi2vTiE?si=DTL4SG7PXgys98m1)
    - [Blog](https://aka.ms/apic/ai)
- Tutorial: [Enable linting and analysis for API governance in your API Center](https://learn.microsoft.com/azure/api-center/enable-api-analysis-linting)

**API Discovery & Consumption - Get started with our VS Code extension:**
- Video: [Introducing the VS Code extension for Azure API Center](https://youtu.be/62X0NALedCc) 
- Documentation: [Get started with the Azure API Center extension for Visual Studio Code](https://learn.microsoft.com/azure/api-center/use-vscode-extension)

**Elevating API Discovery with a self-hosted API Center Portal:**
- Documentation [Self-host your API Center portal](https://learn.microsoft.com/azure/api-center/enable-api-center-portal)
- GitHub Repo [APICenter Portal Starter](https://github.com/Azure/APICenter-Portal-Starter)

**GitHub Example Repos:**
- GitHub Repo: [API Center ❤️ all APIs](https://github.com/Azure-Samples/universal-api-center)

## Roadmap

![APIs view in Azure API Center](media/roadmap/roadmap01232025.png)

> :memo: **Note**: Please note that this roadmap is a living document and may be updated as priorities shift and new information becomes available. We appreciate your understanding and flexibility as we strive to deliver the best possible outcomes

## Now
- <ins>**Inventory**</ins>
    - [x] :white_check_mark: **GitHub Actions support**: Released.
    - [x] :white_check_mark: **APIM / APIC Sync**: Public Preview.
    - [x] :white_check_mark: **Import from AWS**: Public Preview.
    - [ ] **Multiple spec support**: Research phase.
    - [ ] **Azure Functions Integration**: Research phase.
- <ins>**Governance**</ins>
    - [x] :white_check_mark: **Increase linting limit for Standard**: Released.
    - [x] :white_check_mark: **Execution History - API details**: Released.
    - [x] :white_check_mark: **VS Code - GitHub Copilot for Azure Integration**: Released.
    - [x] :white_check_mark: **Managed API Analysis**: Public Preview.
    - [x] :white_check_mark: **API Analysis Dashboard**: Public Preview. 
    - [ ] **Managed Linting - AsyncAPI support**: In Development.
    - [ ] **Support for multiple linting rules -  API Governance Profiles**: In Development.

- <ins>**Discover & Consume**</ins>
    - [ ] **Managed APIC Portal**: In Development.
    - [ ] **API Visibility in APIC Portal**: Research phase.

## Next
- <ins>**Inventory**</ins>
    - [ ] API Access Management (APIM Only)
    - [ ] Deployment Support APIC to APIM
    - [ ] Integration with Apigee
    - [ ] Integration with Azure App Service
- <ins>**Governance**</ins>
    - [ ] Download API Analysis Report
    - [ ] Inventory Analysis & AI-Powered API Duplicate Detection 
    - [ ] API Drift Detection
    - [ ] Breaking Change Detection
    - [ ] Governance Recommendation Engine
- <ins>**Discover & Consume**</ins>
    - [ ] Semantic Search Support
    - [ ] Filtering and searching based on metadata in APIC Portal
    - [ ] API Grouping and Granting Access
    - [ ] APIC Portal Chatbot

## Future
- <ins>**Inventory**</ins>
    - [ ] Integration Mulesoft
    - [ ] Integration Source control: GitHub repository
    - [ ] Integration Source control: Azure DevOps
- <ins>**Governance**</ins>
    - [ ] API dependencies
    - [ ] Usage monitoring
- <ins>**Discover & Consume**</ins>
    - [ ] WordPress Plugin
    - [ ] Backstage Plugin


## How to provide feedback

Your feedback is invaluable to us, and we encourage you to share your thoughts and suggestions in the repository's **Issues** section. *Note: Please search for existing issues to see if your feedback or bug report has already been submitted.* 

We’ll be keeping a close eye on your input to continuously improve. While we’re dedicated to monitoring these issues, please note that this channel is not part of our Microsoft Azure Service Support.

If you prefer to keep the communication private, you can contact the API Center product team directly at apicenter@microsoft.com.

## Other resources

* [Contribution guidelines and policy](CONTRIBUTIONS.md)
* [Security policy](SECURITY.md)
* [Code of conduct policy](CODE_OF_CONDUCT.md)
