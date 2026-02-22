using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.DurableTask.Client;
using Microsoft.Azure.SignalR.Management;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;

namespace InterviewWorkflow
{
    public static class SignalRFunctions
    {
        [Function("negotiate")]
        public static async Task<HttpResponseData> Negotiate(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger("negotiate");
            logger.LogInformation("Negotiate function triggered in India region");

            try
            {
                var body = await req.ReadAsStringAsync();
                if (string.IsNullOrEmpty(body))
                {
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteStringAsync("Request body is required");
                    return badResponse;
                }

                var userInfo = JsonSerializer.Deserialize<SignalRConnectionInfo>(body);
                
                if (string.IsNullOrEmpty(userInfo?.UserId) || string.IsNullOrEmpty(userInfo?.InterviewId))
                {
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteStringAsync("UserId and InterviewId are required");
                    return badResponse;
                }

                var connectionString = Environment.GetEnvironmentVariable("AzureSignalRConnectionString");
                var serviceManager = new ServiceManagerBuilder()
                    .WithOptions(option =>
                    {
                        option.ConnectionString = connectionString;
                    })
                    .BuildServiceManager();

                var hubContext = await serviceManager.CreateHubContextAsync("interviewHub", default);

                await hubContext.UserGroups.AddToGroupAsync(userInfo.UserId, userInfo.InterviewId);

                var negotiateResponse = await hubContext.NegotiateAsync(new NegotiationOptions
                {
                    UserId = userInfo.UserId
                });

                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteAsJsonAsync(negotiateResponse);
                
                logger.LogInformation($"Negotiation successful for user {userInfo.UserId} in interview {userInfo.InterviewId} (India)");
                return response;
            }
            catch (Exception ex)
            {
                logger.LogError($"Negotiation failed in India: {ex.Message}");
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync($"Negotiation failed in India: {ex.Message}");
                return errorResponse;
            }
        }

        [Function("broadcastToInterview")]
        public static async Task<HttpResponseData> BroadcastToInterview(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger("broadcastToInterview");
            logger.LogInformation("Broadcast function triggered in India region");

            try
            {
                var body = await req.ReadAsStringAsync();
                if (string.IsNullOrEmpty(body))
                {
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteStringAsync("Request body is required");
                    return badResponse;
                }

                var message = JsonSerializer.Deserialize<BroadcastMessage>(body);

                if (string.IsNullOrEmpty(message?.InterviewId))
                {
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteStringAsync("InterviewId is required");
                    return badResponse;
                }

                var connectionString = Environment.GetEnvironmentVariable("AzureSignalRConnectionString");
                var serviceManager = new ServiceManagerBuilder()
                    .WithOptions(option =>
                    {
                        option.ConnectionString = connectionString;
                    })
                    .BuildServiceManager();

                var hubContext = await serviceManager.CreateHubContextAsync("interviewHub", default);

                await hubContext.Clients.Group(message.InterviewId).SendCoreAsync("newMessage", new object[] { message });

                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteAsJsonAsync(new { 
                    status = "Message broadcasted", 
                    interviewId = message.InterviewId,
                    region = "India" 
                });
                
                logger.LogInformation($"Message broadcasted to interview {message.InterviewId} in India");
                return response;
            }
            catch (Exception ex)
            {
                logger.LogError($"Broadcast failed in India: {ex.Message}");
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync($"Broadcast failed in India: {ex.Message}");
                return errorResponse;
            }
        }

        [Function("interviewCompleted")]
        public static async Task<HttpResponseData> InterviewCompleted(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req,
            [DurableClient] DurableTaskClient durableClient,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger("interviewCompleted");
            logger.LogInformation("Interview completed function triggered in India region");

            try
            {
                var body = await req.ReadAsStringAsync();
                if (string.IsNullOrEmpty(body))
                {
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteStringAsync("Request body is required");
                    return badResponse;
                }

                var result = JsonSerializer.Deserialize<InterviewResult>(body);

                if (string.IsNullOrEmpty(result?.InterviewId))
                {
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteStringAsync("InterviewId is required");
                    return badResponse;
                }

                await durableClient.RaiseEventAsync(result.InterviewId, "InterviewCompleted", result);

                var connectionString = Environment.GetEnvironmentVariable("AzureSignalRConnectionString");
                var serviceManager = new ServiceManagerBuilder()
                    .WithOptions(option =>
                    {
                        option.ConnectionString = connectionString;
                    })
                    .BuildServiceManager();

                var hubContext = await serviceManager.CreateHubContextAsync("interviewHub", default);
                
                await hubContext.Clients.Group(result.InterviewId).SendCoreAsync("interviewComplete", new object[] { 
                    new {
                        interviewId = result.InterviewId,
                        message = "Interview has been completed",
                        region = "India",
                        timestamp = DateTime.UtcNow
                    }
                });

                var response = req.CreateResponse(HttpStatusCode.OK);
                await response.WriteAsJsonAsync(new { 
                    status = "Interview marked as completed",
                    region = "India" 
                });
                
                return response;
            }
            catch (Exception ex)
            {
                logger.LogError($"Interview completion failed in India: {ex.Message}");
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync($"Failed in India: {ex.Message}");
                return errorResponse;
            }
        }

        // Models
        public class SignalRConnectionInfo
        {
            public string? UserId { get; set; }
            public string? InterviewId { get; set; }
        }

        public class BroadcastMessage
        {
            public string? InterviewId { get; set; }
            public string? UserId { get; set; }
            public string? Content { get; set; }
            public string? Type { get; set; }
            public DateTime Timestamp { get; set; }
        }

        public class InterviewResult
        {
            public string? InterviewId { get; set; }
            public string? Feedback { get; set; }
            public List<QuestionResponse>? Responses { get; set; }
            public DateTime CompletionTime { get; set; }
        }

        public class QuestionResponse
        {
            public string? Question { get; set; }
            public string? Answer { get; set; }
            public int Quality { get; set; }
        }
    }
}