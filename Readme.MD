
# Disclaimer

This project is under heavy development and deployment instructions are likely to be outdated during the current sprint, lasting until late November. 

## Related Repositories
- Traefik fork for provider development: https://github.com/lawrencegripper/traefik/
- Go SF Management SDK: https://github.com/jjcollinge/servicefabric
- sfctl for property management: https://github.com/Azure/service-fabric-cli/pull/53

# Running Traefik on Service Fabric

# What is Traefik?
Træfik (pronounced like traffic) is a modern HTTP reverse proxy and load balancer made to deploy microservices with ease. It supports several backends (Docker, Swarm mode, Kubernetes, Marathon, Consul, Etcd, Rancher, Amazon ECS, and a lot more) to manage its configuration automatically and dynamically.
For more information, visit the [Traefik homepage](https://traefik.io/)

# What is Service Fabric?
Azure Service Fabric is a distributed systems platform that makes it easy to package, deploy, and manage scalable and reliable microservices and containers.
For more information, visit the [Service Fabric homepage](https://azure.microsoft.com/en-gb/services/service-fabric/)

# Why run Traefik on Service Fabric?
Integrating Treafik and Service Fabric allows you to configure much more advanced, yet flexible, traffic routing scenarios for your Service Fabric hosted services and applications. You get all the benefits of using Treafik to configure your routing whilst also getting the benefits of Service Fabric's packaging model.

# How do I get started?
First things first, make sure you have a Service Fabric cluster up and running, either remotely or using the local development environment. Instructions on doing this can be found on the [Service Fabric documentation page](https://docs.microsoft.com/en-gb/azure/service-fabric/).

Once you have a Service Fabric cluster up and running, let's deploy a sample application so you have something to route traffic to. The [Service Fabric Getting Started Sample](https://azure.microsoft.com/en-us/resources/samples/service-fabric-dotnet-getting-started/) is a great starting point. This application contains services for each of the supported service types (Stateless services, Stateful services, Actors services and Guest Executable services [Currently there is no container service although Service Fabric does have support for this type of service]). Once you've deployed the sample application to your cluster we can get started working with Traefik.

1. Clone this repository to your local machine.
    
    `git clone https://github.com/jjcollinge/traefik-on-service-fabric.git`

2. Download the Traefik Binary into the solution by running the following powershell script.

    `./traefik-on-service-fabric/Traefik/Scripts/Get-TraefikBinary.ps1`

    This will use the build from this repositories release. To override this specify a `-url` argument with the URL of a Traefik windows binary.

3. Open the `Traefik.sln` file in Visual Studio

    **If you're working against a local development cluster skip to step 10.**

4. Download or copy your clusters `.pfx` certificate file into the folder `traefik-on-service-fabric\Traefik\Scripts\`. If you have multiple certificates, this should be the one you wish Traefik to use to authenticate against your cluster's management endpoint. Ideally, this will be a `read-only` certificate.

5. Set your execution policy to unrestricted to allow the scripts to run

    `Set-ExectuionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser`

6. Create a passphrase ANSI text file with suitable permissions and write the `*.pfx` passphrase to it.

7. Please read the [Certificates section](#certificates) before running the `Create-Certs.ps1` script... ok read it? Run the `Create-Certs.ps1` script.

    `.\Create-Certs.ps1 -PfxCertFilePath <myclustercert.pfx> -PfxPassphraseFilePath <mypassphrase.txt> -CASubject "/C=GB/ST=England/L=London/O=Jon/CN=www.example.com"`

8. Copy your generated certificate to the folder Traefik expects to find them in        `traefik-on-service-fabric\Traefik\ApplicationPackageRoot\TraefikPkg\Code\certs`

    `cp .\certs\* ..\ApplicationPackageRoot\TraefikPkg\Code\certs\`

9. If you wish to track the new certificate files in Visual Studio, you'll need to add them to your solution by right clicking on the `ApplicationPackageRoot\TreafikPkg\Code\certs` folder and selecting `Add Existing Item...`, navigate to the certificates local on disk and select `Add`.

10. Edit the `traefik-on-service-fabric\Traefik\ApplicationPackageRoot\TraefikPkg\Code\traefik.toml` configuration file. If you're using a secure cluster, uncomment the 3 certificate parameters and make sure they point to the file names we generated earlier. Finally, ensure the `clustermanagementurl` is correct and that the `[servicefabric]` provider tag is uncommented too.

    ```toml
    ################################################################
    # Service Fabric provider
    ################################################################

    # Enable Service Fabric configuration backend
    [servicefabric]

    # Service Fabric Management Endpoint
    clustermanagementurl = "http://localhost:19080"

    # Service Fabric Management Endpoint API Version
    apiversion = "3.0"

    # Client certifcate file path
    # clientcertfilepath = "certs/mycert.crt"

    # Client certifcate key file path
    # clientcertkeyfilepath = "certs/mycert.key"

    # CA certifcate file path
    # cacertfilepath = "certs/cacert.cer"
    ```

11. You now have a choice (Yikes!). See [simple configuration](#simple-configuration) or [advanced configuration](#advanced-configuration) to review your options.

12. Once configured, you can simply publish Traefik from Visual Studio like any other Service Fabric service.

13. To be able to route traffic through the Traefik API and see the dashboard, you'll need to open up and map the relevant ports on the Azure Load Balancer. These ports default to 80 (API) and 8080 (Dashboard) and can be configured in the `traefik-on-service-fabric\Traefik\ApplicationPackageRoot\TraefikPkg\Code\traefik.toml` file and the TraefikPkg's `ServiceManifest.xml`.

14. Once the deployment is complete, you should be able to visit the Traefik dashboard at http[s]://[clusterfqdn]:8080.

    ![img](Docs/Images/traefikonsf.png)

    You should see a single frontend and a number of backends configured.

15. Open your web browser and hit the address http://[clusterfqdn]/GettingStartedApplication/WebService. You should be routed through to the 'Service Fabric Sample Application' home page. You'll notice that the index.html page loads fine but fails to bring in the accompanying assets (.js and .css files). This is because the web application is unaware that it must route it's requests via the Prefix '/GettingStartedApplication/WebService' and is trying to access them at the root path '/'. Traefik passes the stripped route through to the backend web server in the `X-Forwarded-Prefix` header. The web server must use this header to append the prefix to any URLs that will be invoked from the browser to access other assets on the web server.

16. Now that you have a Traefik instance up and running, you can simply update the config by changing either the `ApplicationParameters` or `traefik-on-service-fabric\Traefik\ApplicationPackageRoot\TraefikPkg\Config\config.toml.tmpl` and then running the `traefik-on-service-fabric\Traefik\Scripts\Update-Config.ps1`. This will patch your configuration files (`ApplicationManifest.xml` and `ServiceManifest.xml`), create a config-only Service Fabric application package and kick off a rolling update.

    ```
    .\Update-Config.ps1 -ServiceFabricConnectionEndpoint $clusterfqdn:19000 -PfxCertThumbprint $Thumbprint -SecureCluster 1
    ```

## How does it work?

Traefik is hosted as a Service Fabric Guest Executable. Traefik has a built in Service Fabric [provider](https://github.com/containous/traefik/tree/master/provider) which will query the Service Fabric management API to discover what services are currently being hosted in the cluster (referred to as `backends`). The provider then maps routing rules (known as `frontends`) across these `backends`. Traffic then flows in via `entrypoints` (http, https, etc.), the `frontends` are then applied to load balance and filter traffic to each `backend`. The provider will take into account the `Health` and `Status` of each of the services to ensure traffic is only routed to healthy service instances.

To learn more about the Traefik model of Frontends and Backends [see their documentation](https://docs.traefik.io/basics/).

## Simple Configuration [UPDATE IN PROGRESS]

The simplest way to expose a Service Fabric service via Traefik is by using Service Fabric's `Extension` element in your `ServiceManifest.xml`. 

1. To expose our a service on the path `/testservice` add the `Extensions` section from below into your `ServiceManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<ServiceManifest Name="WebServicePkg"
                 Version="2.0.0"
                 xmlns="http://schemas.microsoft.com/2011/01/fabric"
                 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <ServiceTypes>
    <!-- This is the name of your ServiceType. 
         This name must match the string used in RegisterServiceType call in Program.cs. -->
    <StatelessServiceType ServiceTypeName="WebServiceType">
      <Extensions>
          <Extension Name="Traefik">
            <Labels xmlns="http://schemas.microsoft.com/2015/03/fabact-no-schema">
              <Label Key="traefik.frontend.rule.default">PathPrefixStrip: /thing</Label>
              <Label Key="traefik.expose">true</Label>
              <Label Key="traefik.frontend.passHostHeader">true</Label>
            </Labels>
          </Extension>
      </Extensions>
    </StatelessServiceType>
  </ServiceTypes>

```

2. You can override these at runtime using the Property Management API of the cluster. For example:

```
curl -X PUT \
  'http://localhost:19080/Names/GettingStartedApplication2/WebService/$/GetProperty?api-version=6.0&IncludeValues=true' \
  -d '{
  "PropertyName": "traefik.frontend.rule.default",
  "Value": {
    "Kind": "String",
    "Data": "PathPrefixStrip: /testing"
  },
  "CustomTypeId": "LabelType"
}'
```

The available labels are similar to those supported by the [Docker Provider](https://docs.traefik.io/configuration/backends/docker/). Review these for usage information, in future docs will be updated to detail SF specifics. 

## Advanced Configuration

Traefik has a more advanced features than simple routing, including [Rate limiting](https://docs.traefik.io/basics/#backends) and [Circuit breakers](https://docs.traefik.io/basics/#backends) for backends and [Modifiers](https://docs.traefik.io/basics/#frontends) and [Matchers](https://docs.traefik.io/basics/#matchers) for frontends.

These can all be used and customised when deploying on Service Fabric through a configuration template file. The template file is used to generate a TOML file which configures the Traefik instance. Here are some [examples of Traefik TOML files](https://docs.traefik.io/user-guide/examples/).

To customise your TOML template file, simply edit or replace the default TOML template file located at `traefik-on-service-fabric\Traefik\ApplicationPackageRoot\TraefikPkg\Config\config.toml.tmpl`. Do this before you deploy Treafik for the first time, or use the `Update-Config.ps1` as shown in Step 15 to do an in-place config update.

When writing your custom template files, please note that the Service Fabric Traefik provider will dynamically inject your service endpoints as backend servers. This means you can add configuration such as load balancing rules which will be applied to the injected servers at runtime.

More detail on using the templates can be found [here](Docs/CustomTemplates.MD), along with [samples here](Docs/SampleTemplates).

## Certificates
The `Create-Certs.ps1` script is intended to help bootstrap a simple Traefik deployment to a Service Fabric cluster by generating PEM formatted certificate files from an existing `.pfx` certificate. However, it is not intended as a production-grade solution for securing Traefik.
I recommend you read the [documentation](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security-update-certs-azure) on managing certificates in Azure Service Fabric.

The Traefik provider only requires `Read-Only` access to the Service Fabric API and thus you should ideally use a `Read-Only` certificate.

The `Create-Certs.ps1` script also generates a root CA certificate signed with the same client key. If you require this to be signed by an offical CA or a different key then please comment out this section of the script and manually obtain the root CA certificate. For more information on setting up your own CA please refer to this documentation on [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/introduction.html).

**Warning:** The script currently has to unencrypt the .key file as the Traefik provider doesn't support encrypted client key files. We are working to rectify this. In the meantime, please be careful where you store the unencrypted .key file.
