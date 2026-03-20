using Microsoft.Graph;
using Microsoft.Graph.Models;
using Microsoft.Graph.Users.Item.SendMail;

namespace McpSamples.OutlookEmail.HybridApp.Services;

/// <summary>
/// This provides interfaces for Outlook email service operations.
/// </summary>
public interface IOutlookEmailService
{
    /// <summary>
    /// Sends an email.
    /// </summary>
    /// <param name="title">The email title.</param>
    /// <param name="body">The email body.</param>
    /// <param name="sender">The email sender.</param>
    /// <param name="recipients">The email recipients separated by a comma or semicolon.</param>
    /// <param name="replyTo">The optional reply-to addresses separated by a comma or semicolon.</param>
    /// <returns>The result of the email sending operation.</returns>
    Task<SendMailPostRequestBody> SendEmailAsync(string title, string body, string sender, string recipients, string? replyTo = default);
}

/// <summary>
/// This represents the service entity for Outlook email.
/// </summary>
/// <param name="settings"></param>
/// <param name="logger"></param>
public class OutlookEmailService(GraphServiceClient graph, ILogger<OutlookEmailService> logger) : IOutlookEmailService
{
    /// <inheritdoc />
    public async Task<SendMailPostRequestBody> SendEmailAsync(string title, string body, string sender, string recipients, string? replyTo = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(title, nameof(title));
        ArgumentException.ThrowIfNullOrWhiteSpace(body, nameof(body));
        ArgumentException.ThrowIfNullOrWhiteSpace(sender, nameof(sender));
        ArgumentException.ThrowIfNullOrWhiteSpace(recipients, nameof(recipients));
        var recipientList = ParseAddresses(recipients, nameof(recipients), "At least one recipient is required");
        var replyToList = ParseAddresses(replyTo, nameof(replyTo), "At least one reply-to address is required when replyTo is provided");

        var req = BuildMailRequest(title, body, recipientList, replyToList);

        try
        {
            var user = graph.Users[sender];
            await user.SendMail.PostAsync(req);

            logger.LogInformation("Email sent successfully to {Recipients} with subject: {Subject} from {Sender}.", string.Join(", ", recipientList), title, sender);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to send email to {Recipients} with subject: {Subject} from {Sender}.", string.Join(", ", recipientList), title, sender);
            throw;
        }

        return req;
    }

    private static string[] ParseAddresses(string? addresses, string parameterName, string validationMessage)
    {
        if (string.IsNullOrWhiteSpace(addresses))
        {
            return [];
        }

        var addressList = addresses.Split([',', ';'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (addressList.Length == 0)
        {
            throw new ArgumentException(validationMessage, parameterName);
        }

        return addressList;
    }

    private static SendMailPostRequestBody BuildMailRequest(string title, string body, IEnumerable<string> recipients, IEnumerable<string> replyToRecipients)
    {
        var replyToList = replyToRecipients.Select(r => new Recipient
        {
            EmailAddress = new EmailAddress
            {
                Address = r
            }
        }).ToArray();

        var message = new Message
        {
            Subject = title,
            Body = new ItemBody
            {
                ContentType = BodyType.Text,
                Content = body
            },
            ToRecipients = [.. recipients.Select(r => new Recipient
            {
                EmailAddress = new EmailAddress
                {
                    Address = r
                }
            })],
            ReplyTo = replyToList.Length > 0 ? [.. replyToList] : null
        };

        var req = new SendMailPostRequestBody
        {
            Message = message,
            SaveToSentItems = true
        };

        return req;
    }
}
