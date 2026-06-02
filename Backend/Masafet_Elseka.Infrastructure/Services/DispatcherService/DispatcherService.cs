using Masafet_Elseka.Application.DTOs.Dispatcher;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Interfaces.IDispatcherService;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.DispatcherService
{
    public class DispatcherService: IDispatcherService
    {
        private readonly ICacheService _cacheService;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ILogger<DispatcherService> _logger;
        private readonly Context _context;

        public DispatcherService(ICacheService cacheService, UserManager<ApplicationUser> userManager, ILogger<DispatcherService> logger, Context context)
        {
            _cacheService = cacheService;
            _userManager = userManager;
            _logger = logger;
            _context = context;
        }

        public async Task<string> GetAvailableDispatcherId()
        {
            try
            {
                var key = "AvailableDispatchers";
                var dispatcherKeys = _cacheService.GetData<HashSet<string>>(key);
                if (dispatcherKeys == null || !dispatcherKeys.Any())
                {
                    var dbDispatchers = await _userManager.GetUsersInRoleAsync("Dispatcher");
                    var availableDispatchers = dbDispatchers.Where(d => d.IsAvailable == true)
                        .OrderBy(d => d.LastHandledChatAt).ToList();
                    if (availableDispatchers is null || !availableDispatchers.Any())
                    {
                        availableDispatchers = dbDispatchers.OrderBy(d => d.LastHandledChatAt).ToList();
                    }

                    foreach(var dispatcher in availableDispatchers)
                    {
                        var dispatcherDTO = new DispatcherDTO
                        {
                            Id = dispatcher.Id,
                            IsAvailable = dispatcher.IsAvailable!.Value,
                            LastHandledChatAt = dispatcher.LastHandledChatAt,
                        };
                        var dispatcherKey = $"Dispatcher_{dispatcher.Id}";
                        _cacheService.SetData(dispatcherKey, dispatcherDTO);
                        await _cacheService.SetKeyToList("AvailableDispatchers", dispatcherKey);
                    }
                    return availableDispatchers.FirstOrDefault()?.Id ?? string.Empty;
                }

                var dispatchers = new List<DispatcherDTO>();
                var offlineDispatchers = new List<DispatcherDTO>();
                foreach (var dispatcherKey in dispatcherKeys)
                {
                    var dispatcher = _cacheService.GetData<DispatcherDTO>(dispatcherKey);
                    if (dispatcher != null && dispatcher.IsAvailable)
                    {
                        dispatchers.Add(dispatcher);
                    }
                    if(dispatcher != null && !dispatcher.IsAvailable)
                    {
                        offlineDispatchers.Add(dispatcher);
                    }
                }

                return dispatchers
                    .OrderBy(d => d.LastHandledChatAt)
                    .FirstOrDefault(d => d.IsAvailable)?.Id ??
                    offlineDispatchers.OrderBy(o => o.LastHandledChatAt).FirstOrDefault()?.Id ?? string.Empty;
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        public async Task<bool> UpdateDispatcherAvailability(string id, bool isAvailable)
        {
            try
            {
                var dispatcher = await _userManager.FindByIdAsync(id);
                if (dispatcher == null)
                {
                    return false;
                }
                dispatcher.IsAvailable = isAvailable;
                await _userManager.UpdateAsync(dispatcher);
                await _context.SaveChangesAsync();

                var dispatcherKey = $"Dispatcher_{id}";
                var cachedDispatcher = _cacheService.GetData<DispatcherDTO>(dispatcherKey);
                if (cachedDispatcher == null)
                {
                    cachedDispatcher = new DispatcherDTO
                    {
                        Id = dispatcher.Id,
                        IsAvailable = isAvailable,
                    };
                    _cacheService.SetData(dispatcherKey, cachedDispatcher);
                    return true;
                }
                cachedDispatcher.IsAvailable = isAvailable;
                _cacheService.SetData(dispatcherKey, cachedDispatcher);
                await _cacheService.SetKeyToList("AvailableDispatchers", dispatcherKey);
                _logger.LogInformation("Dispatcher availability updated: {DispatcherId}, IsAvailable: {IsAvailable}", id, isAvailable);
                return true;
            }
            catch (Exception ex)
            {
                return false;
            }
        }
    }
}
