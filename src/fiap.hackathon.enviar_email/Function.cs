using Amazon.Lambda.Core;
using Amazon.Lambda.SQSEvents;
using SendGrid;
using SendGrid.Helpers.Mail;
using System.Text.Json;


// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace fiap.hackathon.enviar_email;

public class Function
{
    public Function()
    {

    }

    public async Task FunctionHandler(SQSEvent sqsEvent, ILambdaContext context)
    {
        var apiKey = Environment.GetEnvironmentVariable("SENDGRID_API_KEY");
        var fromEmail = Environment.GetEnvironmentVariable("EMAIL_FROM");
        var fromName = Environment.GetEnvironmentVariable("NAME_FROM");

        if (string.IsNullOrEmpty(apiKey) || string.IsNullOrEmpty(fromEmail) || string.IsNullOrEmpty(fromName))
        {
            context.Logger.LogError("Environment variables not set correctly.");
            throw new Exception("Missing environment variables. apiKey: " + apiKey);
        }

        var client = new SendGridClient(apiKey);

        foreach (var record in sqsEvent.Records)
        {
            try
            {
                context.Logger.LogInformation($"Processing message: {record.Body}");
                var emailMessage = JsonSerializer.Deserialize<EmailMessage>(record.Body);

                if (emailMessage == null || string.IsNullOrEmpty(emailMessage.Email) || string.IsNullOrEmpty(emailMessage.Assunto))
                {
                    context.Logger.LogWarning("Invalid message format or missing required fields.");
                    continue;
                }

                var from = new EmailAddress(fromEmail, fromName);
                var to = new EmailAddress(emailMessage.Email, emailMessage.Nome);
                var msg = MailHelper.CreateSingleEmail(from, to, emailMessage.Assunto, emailMessage.Corpo, emailMessage.Corpo);
                var response = await client.SendEmailAsync(msg);

                var responseBody = await response.Body.ReadAsStringAsync();
                context.Logger.LogInformation($"Response Status: {response.StatusCode}");
                context.Logger.LogInformation($"Response Body: {responseBody}");

                if (response.StatusCode == System.Net.HttpStatusCode.Accepted)
                {
                    context.Logger.LogInformation($"Email sent successfully to {emailMessage.Email}.");
                }
                else
                {
                    context.Logger.LogError($"Failed to send email. Status Code: {response.StatusCode}. Response: {responseBody}");
                }
            }
            catch (Exception ex)
            {
                context.Logger.LogError($"Error processing message: {ex.Message}");
            }

        }
    }

    public class EmailMessage
    {
        public required string Nome { get; set; }
        public required string Email { get; set; }
        public required string Assunto { get; set; }
        public required string Corpo { get; set; }
    }
}