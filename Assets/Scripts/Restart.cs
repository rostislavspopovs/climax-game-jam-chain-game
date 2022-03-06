using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Restart : MonoBehaviour
{
    public GameObject player;
    public Vector3 playerPos;
    public GameObject ballchain;
    public Vector3 ballchainPos;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKey(KeyCode.R))
        {
            player.transform.position = playerPos;
            player.transform.rotation = Quaternion.identity;
            //player.GetComponent<Rigidbody>().velocty = Vector3.zero;
            ballchain.transform.position = ballchainPos;
            ballchain.transform.rotation = Quaternion.identity;
            //ballchain.GetComponent<Rigidbody>().velocty = Vector3.zero;
        }
    }
}
