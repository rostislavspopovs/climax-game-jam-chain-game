using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Player : MonoBehaviour
{

    public float baseMoveSpeed = 1f;
    public float acc = 0.4f;
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
        int layerMask = 1 << 2;
        layerMask = ~layerMask;
        RaycastHit hit;
        isInAir = !(Physics.Raycast(transform.position, transform.TransformDirection(Vector3.down), out hit, 3, layerMask));
        //Debug.DrawRay(transform.position, transform.TransformDirection(Vector3.down) * (10f), Color.red);
        //Debug.Log(transform.position);
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
            vertVeloc = 20f + 3f*currMoveSpeed;
            RecursiveJump(transform, countJumping(transform));
        }
        //transform.Translate(Vector3.up * vertVeloc * Time.deltaTime);

        currMoveSpeed = Mathf.Max(baseMoveSpeed, Mathf.Min(maxMoveSpeed, currMoveSpeed + acc*accMult*Time.deltaTime));

    }


    void OnCollisionEnter(Collision collisionInfo)
    {
        Debug.Log(collisionInfo.collider.name);
        if (collisionInfo.collider.name == "Platform Part A")
        {
            Debug.Log("Success!");
            isInAir = false;
            vertVeloc = 0f;
        }
    }

    void OnCollisionExit(Collision collisionInfo)
    {
        if (collisionInfo.collider.name == "Platform Part A")
        {
            isInAir = true;
        }
    }

    void RecursiveJump(Transform parent, int numJumpers)
    {
        if (parent.GetComponent<Rigidbody>() != null)
            {
                parent.GetComponent<Rigidbody>().AddForce(Vector3.up * vertVeloc/numJumpers);
            }
        foreach (Transform child in parent)
        {
            
            RecursiveJump(child, numJumpers);
        }
    }

    int countJumping(Transform parent)
    {
        int count;
        if (parent.GetComponent<Rigidbody>() != null)
        {
            count = 1;
        }
        else
        {
            count = 0;
        }
        foreach (Transform child in parent)
        {
            count += countJumping(child);
        }
        return count;
    }
}
