using Glasswall.IcapServer.CloudProxyApp.Configuration;
using Glasswall.IcapServer.CloudProxyApp.Setup;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System;
using System.Threading.Tasks;

namespace Glasswall.IcapServer.CloudProxyApp
{
    class Program
    {
        static IServiceProvider _serviceProvider;

        static async Task<int> Main(string[] args)
        {
            IConfiguration configuration = new ConfigurationBuilder()
              .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
              .AddEnvironmentVariables()
              .AddCommandLine(args, CommandLineSwitchMapping.Mapping)
              .Build();

            try
            {
                var services = new ServiceCollection();
                _serviceProvider = services.
                    ConfigureCloudFactories().                    
                    ConfigureServices(configuration).
                    BuildServiceProvider(true);
                return await _serviceProvider.GetRequiredService<CloudProxyApplication>().RunAsync();
            }
            catch(InvalidApplicationConfigurationException iace)
            {
                _serviceProvider?.GetService<ILogger<Program>>().LogError(iace, "Invalid Configuration");
                return (int)ReturnOutcome.GW_ERROR;
            }
            catch(Exception ex)
            {
                _serviceProvider?.GetService<ILogger<Program>>().LogError(ex, "Processing Error");
                return (int)ReturnOutcome.GW_ERROR;
            }
            finally
            {
                DisposeServices();
            }
        }
        #checking this code
            string = "1234"
        private static void DisposeServices()
        {
            if (_serviceProvider == null)
                return;

            if (_serviceProvider is IDisposable disposable)
            {
                disposable.Dispose();
            }
        }
    }
}
