using Google.Apis.Auth;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.AuthState;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Collections.Concurrent;

public class AuthStateService : IAuthStateService
{
    private readonly ConcurrentDictionary<string, AuthState> _states;
    private readonly TimeSpan _stateExpiry = TimeSpan.FromMinutes(10);
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _configuration;

    public AuthStateService(IServiceProvider serviceProvider, IConfiguration configuration)
    {
        _states = new ConcurrentDictionary<string, AuthState>();
        _serviceProvider = serviceProvider;
        _configuration = configuration;
    }

    public void AddState(string state)
    {
        _states[state] = new AuthState
        {
            State = state,
            CreatedAt = DateTime.UtcNow,
            Status = "pending"
        };
        CleanupExpiredStates();
    }

    public async Task<bool> CompleteState(string state, string code)
    {
        if (!_states.TryGetValue(state, out var authState))
        {
            return false;
        }

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var googleAuthService = scope.ServiceProvider.GetRequiredService<IGoogleAuthService>();

            var loginResult = await googleAuthService.ExchangeCodeForTokenMobileAsync(code);

            if (!loginResult.IsSuccess || loginResult.Data == null)
            {
                authState.Status = "failed";
                return false;
            }

            authState.Code = code;
            authState.Status = "completed";
            authState.IsUsed = false;
            authState.UserData = loginResult.Data;
            authState.Token = loginResult.Data.Token;
            authState.RefreshToken = loginResult.Data.RefreshToken;

            return true;
        }
        catch (Exception ex)
        {
            authState.Status = "failed";
            return false;
        }
    }

    public AuthState GetState(string state)
    {
        if (_states.TryGetValue(state, out var authState))
        {
            if (DateTime.UtcNow - authState.CreatedAt > _stateExpiry)
            {
                _states.TryRemove(state, out _);
                return null;
            }
            return authState;
        }
        return null;
    }

    private void CleanupExpiredStates()
    {
        var expired = _states.Where(x =>
            DateTime.UtcNow - x.Value.CreatedAt > _stateExpiry).ToList();

        foreach (var state in expired)
        {
            _states.TryRemove(state.Key, out _);
        }
    }

    void IAuthStateService.CleanupExpiredStates()
    {
        CleanupExpiredStates();
    }
}