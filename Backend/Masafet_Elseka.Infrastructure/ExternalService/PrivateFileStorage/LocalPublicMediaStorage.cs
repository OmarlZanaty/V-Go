using Masafet_Elseka.Application.Interfaces.IPrivateFileStorage;
using Microsoft.Extensions.Configuration;

namespace Masafet_Elseka.Infrastructure.ExternalService.PrivateFileStorage
{
    // Saves public images under Storage:PublicRoot; Program.cs serves that folder at
    // /media. URLs are absolute when App:PublicBaseUrl is set (the API sits behind a
    // proxy, so the request host isn't reliable).
    public class LocalPublicMediaStorage : IPublicMediaStorage
    {
        public const string RequestPath = "/media";

        private readonly string _root;
        private readonly string _baseUrl;

        public LocalPublicMediaStorage(IConfiguration configuration)
        {
            _root = Path.GetFullPath(RootFrom(configuration));
            _baseUrl = (configuration["App:PublicBaseUrl"] ?? string.Empty).TrimEnd('/');
        }

        public static string RootFrom(IConfiguration configuration) =>
            configuration["Storage:PublicRoot"] ?? Path.Combine(AppContext.BaseDirectory, "public-media");

        public async Task<string> SaveAsync(Stream content, string folder, string extension)
        {
            var safeFolder = string.Join('/', folder.Split('/', '\\')
                .Where(p => p.Length > 0 && p != "." && p != ".."));
            var relative = $"{safeFolder}/{Guid.NewGuid():N}{extension}";
            var full = Path.GetFullPath(Path.Combine(_root, relative));
            if (!full.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
                throw new InvalidOperationException("Invalid media path");

            Directory.CreateDirectory(Path.GetDirectoryName(full)!);
            await using (var file = new FileStream(full, FileMode.CreateNew, FileAccess.Write))
                await content.CopyToAsync(file);

            return $"{_baseUrl}{RequestPath}/{relative}";
        }

        public void Delete(string url)
        {
            try
            {
                var marker = $"{RequestPath}/";
                var i = url.IndexOf(marker, StringComparison.Ordinal);
                if (i < 0) return; // not ours (e.g. an old Cloudinary URL)
                var full = Path.GetFullPath(Path.Combine(_root, url[(i + marker.Length)..]));
                if (full.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.Ordinal) && File.Exists(full))
                    File.Delete(full);
            }
            catch
            {
                // A leftover file is harmless; never fail the request over cleanup.
            }
        }
    }
}
