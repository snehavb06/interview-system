using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.DurableTask;
using Microsoft.DurableTask.Client;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;
using Microsoft.ApplicationInsights;

namespace InterviewWorkflow
{
    public static class InterviewOrchestrator
    {
        [Function("StartInterview")]
        public static async Task<HttpResponseData> StartInterview(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req,
            [DurableClient] DurableTaskClient client,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger("StartInterview");
            var telemetry = executionContext.InstanceServices.GetService<TelemetryClient>();
            
            logger.LogInformation("StartInterview triggered in India region");
            
            try
            {
                var requestBody = await req.ReadAsStringAsync();
                var interviewData = JsonSerializer.Deserialize<InterviewRequest>(requestBody ?? "{}");
                
                string instanceId = string.IsNullOrEmpty(interviewData?.IdempotencyKey) 
                    ? Guid.NewGuid().ToString() 
                    : interviewData.IdempotencyKey;
                
                var existingInstance = await client.GetInstanceAsync(instanceId);
                if (existingInstance != null)
                {
                    telemetry?.TrackEvent("InterviewAlreadyExists", new Dictionary<string, string>
                    {
                        ["InterviewId"] = instanceId,
                        ["Region"] = "India"
                    });
                    
                    var response = req.CreateResponse(HttpStatusCode.OK);
                    await response.WriteAsJsonAsync(new { 
                        instanceId = instanceId,
                        status = existingInstance.RuntimeStatus.ToString(),
                        message = "Interview already started",
                        region = "India"
                    });
                    return response;
                }
                
                await client.ScheduleNewOrchestrationInstanceAsync(
                    nameof(InterviewWorkflowOrchestrator),
                    new InterviewOrchestrationInput
                    {
                        InterviewId = instanceId,
                        CandidateEmail = interviewData?.CandidateEmail ?? "unknown@example.com",
                        InterviewerEmail = interviewData?.InterviewerEmail ?? "unknown@example.com",
                        ScheduledTime = interviewData?.ScheduledTime ?? DateTime.UtcNow.AddHours(1)
                    },
                    new StartOrchestrationOptions { InstanceId = instanceId });
                
                telemetry?.TrackEvent("InterviewStarted", new Dictionary<string, string>
                {
                    ["InterviewId"] = instanceId,
                    ["CandidateEmail"] = interviewData?.CandidateEmail ?? "unknown",
                    ["Region"] = "India"
                });
                
                var acceptedResponse = req.CreateResponse(HttpStatusCode.Accepted);
                await acceptedResponse.WriteAsJsonAsync(new { 
                    instanceId = instanceId,
                    statusQueryUri = $"/api/runtime/webhooks/durabletask/instances/{instanceId}",
                    region = "India"
                });
                
                return acceptedResponse;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error starting interview in India region");
                telemetry?.TrackException(ex, new Dictionary<string, string>
                {
                    ["Operation"] = "StartInterview",
                    ["Region"] = "India"
                });
                
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync($"Error in India region: {ex.Message}");
                return errorResponse;
            }
        }

        [Function("InterviewWorkflowOrchestrator")]
        public static async Task<string> InterviewWorkflowOrchestrator(
            [OrchestrationTrigger] TaskOrchestrationContext context)
        {
            var logger = context.CreateReplaySafeLogger("InterviewWorkflowOrchestrator");
            var input = context.GetInput<InterviewOrchestrationInput>()!;
            
            logger.LogInformation($"Starting interview workflow in India for {input.CandidateEmail}");
            
            context.SetCustomStatus(new { 
                Status = "Started", 
                InterviewId = input.InterviewId,
                Region = "India",
                StartTime = DateTime.UtcNow 
            });
            
            try
            {
                // Step 1: Send calendar invitation
                var calendarResult = await context.CallActivityAsync<CalendarResult>(
                    nameof(SendCalendarInvitation),
                    new CalendarInput 
                    { 
                        CandidateEmail = input.CandidateEmail,
                        InterviewerEmail = input.InterviewerEmail,
                        ScheduledTime = input.ScheduledTime,
                        InterviewId = input.InterviewId
                    },
                    new TaskOptions(new RetryPolicy(3, TimeSpan.FromSeconds(30))));
                
                if (!calendarResult.Success)
                {
                    throw new Exception("Failed to send calendar invitation");
                }
                
                context.SetCustomStatus(new { 
                    Status = "AwaitingConfirmation", 
                    InterviewId = input.InterviewId,
                    Region = "India" 
                });
                
                // Step 2: Wait for confirmation (2 hours IST timezone consideration)
                var confirmationEvent = await context.WaitForExternalEvent<ConfirmationEvent>(
                    "CandidateConfirmation",
                    TimeSpan.FromHours(2));
                
                if (confirmationEvent == null)
                {
                    logger.LogWarning($"No confirmation received for interview {input.InterviewId}");
                    
                    context.SetCustomStatus(new { 
                        Status = "ReminderSent", 
                        InterviewId = input.InterviewId,
                        Region = "India" 
                    });
                    
                    await context.CallActivityAsync(
                        nameof(SendReminderEmail),
                        new ReminderInput 
                        { 
                            InterviewId = input.InterviewId,
                            Reason = "No confirmation received"
                        });
                    
                    confirmationEvent = await context.WaitForExternalEvent<ConfirmationEvent>(
                        "CandidateConfirmation",
                        TimeSpan.FromHours(1));
                    
                    if (confirmationEvent == null)
                    {
                        return "Interview cancelled - no response from candidate";
                    }
                }
                
                context.SetCustomStatus(new { 
                    Status = "Confirmed", 
                    InterviewId = input.InterviewId,
                    Region = "India",
                    ConfirmationTime = confirmationEvent.ConfirmationTime 
                });
                
                // Step 3: Prepare materials
                await context.CallActivityAsync(
                    nameof(PrepareInterviewMaterials),
                    new MaterialsInput { InterviewId = input.InterviewId });
                
                context.SetCustomStatus(new { 
                    Status = "InProgress", 
                    InterviewId = input.InterviewId,
                    Region = "India" 
                });
                
                // Step 4: Wait for interview completion
                var interviewCompleted = await context.WaitForExternalEvent<InterviewResult>(
                    "InterviewCompleted",
                    TimeSpan.FromHours(3));
                
                if (interviewCompleted == null)
                {
                    context.SetCustomStatus(new { 
                        Status = "Overdue", 
                        InterviewId = input.InterviewId,
                        Region = "India" 
                    });
                    
                    await context.CallActivityAsync(
                        nameof(HandleOverdueInterview),
                        new OverdueInput { InterviewId = input.InterviewId });
                    
                    return "Interview marked as incomplete - time limit exceeded";
                }
                
                // Step 5: Process results
                var result = await context.CallActivityAsync<FinalResult>(
                    nameof(ProcessInterviewResults),
                    interviewCompleted);
                
                context.SetCustomStatus(new { 
                    Status = "Completed", 
                    InterviewId = input.InterviewId,
                    Region = "India",
                    Outcome = result.Outcome,
                    Score = result.Score 
                });
                
                return $"Interview completed successfully in India region. Result: {result.Outcome}";
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Orchestration failed for interview {input.InterviewId}");
                
                context.SetCustomStatus(new { 
                    Status = "Failed", 
                    InterviewId = input.InterviewId,
                    Region = "India",
                    Error = ex.Message 
                });
                
                await context.CallActivityAsync(
                    nameof(HandleWorkflowFailure),
                    new FailureInput 
                    { 
                        InterviewId = input.InterviewId,
                        ErrorMessage = ex.Message 
                    });
                
                throw;
            }
        }

        [Function("SendCalendarInvitation")]
        public static async Task<CalendarResult> SendCalendarInvitation(
            [ActivityTrigger] CalendarInput input,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger(nameof(SendCalendarInvitation));
            var telemetry = executionContext.InstanceServices.GetService<TelemetryClient>();
            
            logger.LogInformation($"Sending calendar invitation for interview {input.InterviewId} in India");
            
            try
            {
                // Simulate sending calendar invitation
                await Task.Delay(1000);
                
                telemetry?.TrackEvent("CalendarInvitationSent", new Dictionary<string, string>
                {
                    ["InterviewId"] = input.InterviewId,
                    ["CandidateEmail"] = input.CandidateEmail,
                    ["Region"] = "India"
                });
                
                return new CalendarResult { Success = true, MeetingId = Guid.NewGuid().ToString() };
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Failed to send calendar invitation: {ex.Message}");
                telemetry?.TrackException(ex, new Dictionary<string, string>
                {
                    ["InterviewId"] = input.InterviewId,
                    ["Region"] = "India"
                });
                
                return new CalendarResult { Success = false, ErrorMessage = ex.Message };
            }
        }

        [Function("SendReminderEmail")]
        public static async Task SendReminderEmail(
            [ActivityTrigger] ReminderInput input,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger(nameof(SendReminderEmail));
            logger.LogInformation($"Sending reminder for interview {input.InterviewId} in India: {input.Reason}");
            await Task.Delay(500);
        }

        [Function("PrepareInterviewMaterials")]
        public static async Task PrepareInterviewMaterials(
            [ActivityTrigger] MaterialsInput input,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger(nameof(PrepareInterviewMaterials));
            logger.LogInformation($"Preparing materials for interview {input.InterviewId} in India");
            await Task.Delay(2000);
        }

        [Function("HandleOverdueInterview")]
        public static async Task HandleOverdueInterview(
            [ActivityTrigger] OverdueInput input,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger(nameof(HandleOverdueInterview));
            logger.LogInformation($"Handling overdue interview {input.InterviewId} in India");
            await Task.Delay(500);
        }

        [Function("ProcessInterviewResults")]
        public static async Task<FinalResult> ProcessInterviewResults(
            [ActivityTrigger] InterviewResult input,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger(nameof(ProcessInterviewResults));
            var telemetry = executionContext.InstanceServices.GetService<TelemetryClient>();
            
            logger.LogInformation($"Processing results for interview {input.InterviewId} in India");
            
            var outcome = input.Feedback?.Contains("excellent") == true ? "Passed" : "Review Required";
            var score = CalculateScore(input);
            
            telemetry?.TrackEvent("InterviewProcessed", new Dictionary<string, string>
            {
                ["InterviewId"] = input.InterviewId,
                ["Outcome"] = outcome,
                ["Score"] = score.ToString(),
                ["Region"] = "India"
            });
            
            return new FinalResult 
            { 
                InterviewId = input.InterviewId,
                Outcome = outcome,
                Score = score
            };
        }

        [Function("HandleWorkflowFailure")]
        public static async Task HandleWorkflowFailure(
            [ActivityTrigger] FailureInput input,
            FunctionContext executionContext)
        {
            var logger = executionContext.GetLogger(nameof(HandleWorkflowFailure));
            var telemetry = executionContext.InstanceServices.GetService<TelemetryClient>();
            
            logger.LogError($"Workflow failed for interview {input.InterviewId} in India: {input.ErrorMessage}");
            
            telemetry?.TrackEvent("WorkflowFailed", new Dictionary<string, string>
            {
                ["InterviewId"] = input.InterviewId,
                ["ErrorMessage"] = input.ErrorMessage,
                ["Region"] = "India"
            });
            
            await Task.Delay(500);
        }

        private static int CalculateScore(InterviewResult result)
        {
            if (result.Responses == null || result.Responses.Count == 0)
                return 0;
            
            return (int)Math.Round(result.Responses.Average(r => r.Quality));
        }
    }

    // Models
    public class InterviewRequest
    {
        public string? CandidateEmail { get; set; }
        public string? InterviewerEmail { get; set; }
        public DateTime ScheduledTime { get; set; }
        public string? IdempotencyKey { get; set; }
    }

    public class InterviewOrchestrationInput
    {
        public string InterviewId { get; set; } = "";
        public string CandidateEmail { get; set; } = "";
        public string InterviewerEmail { get; set; } = "";
        public DateTime ScheduledTime { get; set; }
    }

    public class CalendarInput
    {
        public string CandidateEmail { get; set; } = "";
        public string InterviewerEmail { get; set; } = "";
        public DateTime ScheduledTime { get; set; }
        public string InterviewId { get; set; } = "";
    }

    public class CalendarResult
    {
        public bool Success { get; set; }
        public string MeetingId { get; set; } = "";
        public string ErrorMessage { get; set; } = "";
    }

    public class ConfirmationEvent
    {
        public string InterviewId { get; set; } = "";
        public bool Confirmed { get; set; }
        public DateTime ConfirmationTime { get; set; }
    }

    public class ReminderInput
    {
        public string InterviewId { get; set; } = "";
        public string Reason { get; set; } = "";
    }

    public class MaterialsInput
    {
        public string InterviewId { get; set; } = "";
    }

    public class InterviewResult
    {
        public string InterviewId { get; set; } = "";
        public string Feedback { get; set; } = "";
        public List<QuestionResponse> Responses { get; set; } = new();
        public DateTime CompletionTime { get; set; }
    }

    public class QuestionResponse
    {
        public string Question { get; set; } = "";
        public string Answer { get; set; } = "";
        public int Quality { get; set; }
    }

    public class FinalResult
    {
        public string InterviewId { get; set; } = "";
        public string Outcome { get; set; } = "";
        public int Score { get; set; }
    }

    public class FailureInput
    {
        public string InterviewId { get; set; } = "";
        public string ErrorMessage { get; set; } = "";
    }

    public class OverdueInput
    {
        public string InterviewId { get; set; } = "";
    }
}