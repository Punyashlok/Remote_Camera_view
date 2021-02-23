using Microsoft.MixedReality.WebRTC.Unity;
using System.Collections;
using UnityEngine;

public class MainController : MonoBehaviour
{
    public static MainController instance;

    public Camera mainCamera;

    public PeerConnection peerConnection;

    /// <summary>
    /// MS WebRTC lib only renders tex to a GO's mesh. We can't permanently change
    /// its code to let it render to skybox (the change will reverse after restarting Unity).
    /// So here in LateUpdate(), if the YUVTransfer is turned on, we will assign the 
    /// shader's YUV plane info in the streamOutMat to skyboxMat.
    /// </summary>
    public bool YUVTransfer = true; 
    public MeshRenderer streamOutMesh;
    private IEnumerator coroutine;
    private Material skyboxMat;
    private Material streamOutMat;

    public GameObject remoteVideoPlayerObj;

    private void Awake()
    {
        instance = this;
    }

    void Start()
    {
        // starts connection
        coroutine = LaunchCall(peerConnection);
        StartCoroutine(coroutine);

        // set up skybox rendering
        skyboxMat = RenderSettings.skybox;
        streamOutMat = streamOutMesh.materials[0];
    }

    private void LateUpdate()
    {
        if (YUVTransfer)
        {
            SetYUVTransfer();
        }
    }

    private IEnumerator LaunchCall(PeerConnection pc)
    {
        yield return new WaitForSeconds(5);
        pc.StartConnection();
        yield return null;
    }

    public void SetYUVTransfer()
    {
        Texture2D _textureY = (Texture2D)streamOutMat.GetTexture("_YPlane");
        Texture2D _textureU = (Texture2D)streamOutMat.GetTexture("_UPlane");
        Texture2D _textureV = (Texture2D)streamOutMat.GetTexture("_VPlane");
        skyboxMat.SetTexture("_YPlane", _textureY);
        skyboxMat.SetTexture("_UPlane", _textureU);
        skyboxMat.SetTexture("_VPlane", _textureV);
    }
}
