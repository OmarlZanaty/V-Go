using Masafet_Elseka.Application.Interfaces.IPrivateFileStorage;
using Microsoft.Extensions.Configuration;

namespace Masafet_Elseka.Infrastructure.ExternalService.PrivateFileStorage
{
    // Stores files on the server's private volume (Storage:PrivateRoot, mounted outside
    // wwwroot). Nothing here is reachable by URL; controllers stream files to admins.
    public class LocalPrivateFileStorage : IPrivateFileStorage
    {
        private readonly string _root;

        public LocalPrivateFileStorage(IConfiguration configuration)
        {
            _root = Path.GetFullPath(configuration["Storage:PrivateRoot"]
                ?? Path.Combine(AppContext.BaseDirectory, "private-data"));
        }

        // Resolves a stored relative path and refuses anything that escapes the root.
        private string Resolve(string relativePath)
        {
            var full = Path.GetFullPath(Path.Combine(_root, relativePath));
            if (!full.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
                throw new InvalidOperationException("Invalid storage path");
            return full;
        }

        public async Task<string> SaveAsync(Stream content, string folder, string extension)
        {
            var safeFolder = string.Join('/', folder.Split('/', '\\')
                .Where(p => p.Length > 0 && p != "." && p != ".."));
            var relative = $"{safeFolder}/{Guid.NewGuid():N}{extension}";
            var full = Resolve(relative);
            Directory.CreateDirectory(Path.GetDirectoryName(full)!);
            await using var file = new FileStream(full, FileMode.CreateNew, FileAccess.Write);
            await content.CopyToAsync(file);
            return relative;
        }

        public async Task<byte[]?> ReadAsync(string relativePath)
        {
            var full = Resolve(relativePath);
            return File.Exists(full) ? await File.ReadAllBytesAsync(full) : null;
        }

        public void Delete(string relativePath)
        {
            try
            {
                var full = Resolve(relativePath);
                if (File.Exists(full)) File.Delete(full);
            }
            catch
            {
                // A leftover file is harmless; never fail the request over cleanup.
            }
        }
    }
}
