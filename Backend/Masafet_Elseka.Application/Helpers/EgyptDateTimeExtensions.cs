using System;

public static class EgyptDateTimeExtensions
{
    // Egypt Time Zone (Eastern European Time - EET)
    private static readonly TimeZoneInfo EgyptTimeZone = TimeZoneInfo.FindSystemTimeZoneById("Egypt Standard Time");

    // Alternative time zone IDs for different platforms
    private static readonly string[] PossibleTimeZoneIds =
    {
        "Egypt Standard Time",
        "Africa/Cairo", 
        "E. Europe Standard Time"
    };

    static EgyptDateTimeExtensions()
    {
        EgyptTimeZone = GetEgyptTimeZone();
    }

    private static TimeZoneInfo GetEgyptTimeZone()
    {
        foreach (var timeZoneId in PossibleTimeZoneIds)
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
            }
            catch (TimeZoneNotFoundException)
            {
                continue;
            }
        }

        return TimeZoneInfo.CreateCustomTimeZone(
            "Egypt Standard Time",
            TimeSpan.FromHours(2),
            "Egypt Standard Time",
            "Egypt Standard Time");
    }

    /// <summary>
    /// Converts a DateTime to Egypt time
    /// </summary>
    public static DateTime ToEgyptTime(this DateTime dateTime)
    {
        if (dateTime.Kind == DateTimeKind.Unspecified)
        {
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(dateTime, DateTimeKind.Utc), EgyptTimeZone);
        }

        return TimeZoneInfo.ConvertTime(dateTime, EgyptTimeZone);
    }

    /// <summary>
    /// Converts a DateTimeOffset to Egypt time
    /// </summary>
    public static DateTimeOffset ToEgyptTime(this DateTimeOffset dateTimeOffset)
    {
        return TimeZoneInfo.ConvertTime(dateTimeOffset, EgyptTimeZone);
    }

    /// <summary>
    /// Gets current Egypt time
    /// </summary>
    public static DateTime EgyptNow => TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, EgyptTimeZone);

    /// <summary>
    /// Gets today's date in Egypt time
    /// </summary>
    public static DateTime EgyptToday => EgyptNow.Date;

    /// <summary>
    /// Converts Egypt time to UTC
    /// </summary>
    public static DateTime ToUtcFromEgyptTime(this DateTime egyptTime)
    {
        if (egyptTime.Kind == DateTimeKind.Utc)
            return egyptTime;

        return TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(egyptTime, DateTimeKind.Unspecified), EgyptTimeZone);
    }

    /// <summary>
    /// Checks if daylight saving time is active in Egypt for the given date
    /// </summary>
    public static bool IsEgyptDaylightSavingTime(this DateTime dateTime)
    {
        var egyptTime = dateTime.ToEgyptTime();
        return EgyptTimeZone.IsDaylightSavingTime(egyptTime);
    }

    /// <summary>
    /// Gets the Egypt time zone information
    /// </summary>
    public static TimeZoneInfo GetEgyptTimeZoneInfo() => EgyptTimeZone;
}