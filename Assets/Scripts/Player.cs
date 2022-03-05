using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Player : MonoBehaviour
{

    public float baseMoveSpeed = 1f;
    public float acc = 0.2f;
    public float maxMoveSpeed = 2f;
    public float currMoveSpeed;
    public bool isInAir;
    public float vertVeloc = 0f;
    public float startJumpHeight;

    // Start is called before the first frame update
    void Start()
    {
        currMoveSpeed = baseMoveSpeed;
        isInAir = true;

    }

    // Update is called once per frame
    void Update()
    {
        
        transform.Translate(Vector3.forward * currMoveSpeed * Time.deltaTime);
        float accMult = -1f;
        if (Input.GetKey(KeyCode.W))
        {
            accMult = 1f;
        }
        else if (Input.GetKey(KeyCode.S))
        {
            accMult = -2f;
        }
        if (Input.GetKey(KeyCode.A))
        {
            transform.Translate(Vector3.left * 5 * Time.deltaTime);
        }
        else if (Input.GetKey(KeyCode.D))
        {
            transform.Translate(Vector3.right * 5 * Time.deltaTime);
        }

        if (Input.GetKey(KeyCode.Space) && !isInAir)
        {
            vertVeloc = 5f + 0.75f*currMoveSpeed;
        }
        transform.Translate(Vector3.up * vertVeloc * Time.deltaTime);
        if (isInAir){
            vertVeloc -= 5f*Time.deltaTime;
        }

        currMoveSpeed = Mathf.Max(baseMoveSpeed, Mathf.Min(maxMoveSpeed, currMoveSpeed + acc*accMult*Time.deltaTime));

    }


    void OnTriggerEnter(Collider collisionInfo)
    {
        Debug.Log(collisionInfo.name);
        if (collisionInfo.name == "Ground")
        {
            Debug.Log("Success!");
            isInAir = false;
            vertVeloc = 0f;
        }
    }

    void OnTriggerExit(Collider collisionInfo)
    {
        if (collisionInfo.name == "Ground")
        {
            isInAir = true;
        }
    }
}
