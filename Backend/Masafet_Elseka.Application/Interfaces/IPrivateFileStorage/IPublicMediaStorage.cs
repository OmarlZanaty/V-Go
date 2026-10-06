namespace Masafet_Elseka.Application.Interfaces.IPrivateFileStorage
{
    // Public images (captain profile photos) stored on the server and served at /media.
    // Used when Cloudinary isn't configured on the host.
    public interface IPublicMediaStorage
    {
        // Returns the public URL of the saved file.
        Task<string> SaveAsync(Stream content, string folder, string extension);
        // Removes a file previously returned by SaveAsync; ignores URLs it doesn't own.
        void Delete(string url);
    }
}
