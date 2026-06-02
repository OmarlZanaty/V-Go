using Hangfire;
using Masafet_Elseka.Infrastructure.Services.ChatService;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.ChatBGService
{
    public class ChatBackgroundService
    {
        public void CloseChat()
        {
            RecurringJob.AddOrUpdate<ChatService>(
                "CloseOpenedChats",
                service => service.HandleUnClosedChats(CancellationToken.None),
                "0 */12 * * *"
            );
        }
    }
}
