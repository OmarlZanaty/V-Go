using Masafet_Elseka.Application.DTOs.Rating;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Hubs
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class RatingHub:Hub
    {
        private readonly IRatingService _ratingService;
        private static readonly ConcurrentDictionary<string, HashSet<string>> _usersConnectionMap = new();

        public RatingHub(IRatingService ratingService)
        {
            _ratingService = ratingService;
        }

        public override async Task OnConnectedAsync()
        {
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrEmpty(userId))
            {
                _usersConnectionMap.AddOrUpdate(
                    userId,
                    new HashSet<string> { Context.ConnectionId },
                    (key, connections) =>
                    {
                        lock (connections)
                        {
                            connections.Add(Context.ConnectionId);
                            return connections;
                        }
                    }
                );
            }

            await base.OnConnectedAsync();
        }

        public async Task SendRating(RatingDTO rate)
        {
            var response = await _ratingService.AddRateAsync(rate);
            if (!response.IsSuccess)
            {
                await Clients.Caller.SendAsync("ReceiveRating", response.Message);
                throw new Exception(response.Message);
            }

            if (_usersConnectionMap.TryGetValue(rate.ToUserId, out var userConnections))
            {
                foreach (var connectionId in userConnections)
                {
                    await Clients.Client(connectionId).SendAsync("ReceiveRating", response.Data);
                }
            }
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrEmpty(userId))
            {
                if (_usersConnectionMap.TryGetValue(userId, out var userConnections))
                {
                    lock (userConnections)
                    {
                        userConnections.Remove(Context.ConnectionId);
                        if (userConnections.Count == 0)
                            _usersConnectionMap.TryRemove(userId, out _);
                    }
                }
            }

            await base.OnDisconnectedAsync(exception);
        }
    }
}
