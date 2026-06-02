# Cloud Run-ready Dockerfile for the V-Go backend.
# Build context must be the Backend/ folder (the one containing the .sln).

# ---------- build ----------
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy everything and restore against the solution so all project references resolve.
COPY . .
RUN dotnet restore "Masafet_Elseka.Presentation/Masafet_Elseka.Presentation.csproj"
RUN dotnet publish "Masafet_Elseka.Presentation/Masafet_Elseka.Presentation.csproj" \
    -c Release -o /app/publish /p:UseAppHost=false

# ---------- runtime ----------
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

# Cloud Run sends traffic to $PORT (default 8080); the app reads it in Program.cs.
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Masafet_Elseka.Presentation.dll"]
